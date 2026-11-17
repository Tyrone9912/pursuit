#!/usr/bin/env node
// Local job-hunt dashboard server. Serves the dashboard page and a small
// JSON API backed by a flat file, so both the headless sweep script and
// the dashboard page talk to the same store. Binds to localhost only;
// phone access goes through `tailscale serve`, which proxies the tailnet
// to this port without the app itself listening on any network interface.
"use strict";

const http = require("http");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const DIR = __dirname;
const DATA_FILE = path.join(DIR, "data", "matches.json");
const DASHBOARD_FILE = path.join(DIR, "dashboard.html");
const PORT = 8787;
const TOKEN = fs.readFileSync(path.join(DIR, "server.token"), "utf8").trim();

fs.mkdirSync(path.join(DIR, "data"), { recursive: true });
if (!fs.existsSync(DATA_FILE)) fs.writeFileSync(DATA_FILE, "[]");

// Single in-process write queue - avoids interleaved read-modify-write
// corruption between concurrent requests (the sweep script and the
// dashboard can both write around the same time).
let writeChain = Promise.resolve();
function withStore(fn) {
  writeChain = writeChain.then(async () => {
    const matches = JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
    const result = await fn(matches);
    fs.writeFileSync(DATA_FILE, JSON.stringify(matches, null, 2));
    return result;
  });
  return writeChain;
}

function readStore() {
  return JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
}

function send(res, status, body, contentType) {
  res.writeHead(status, { "Content-Type": contentType || "application/json" });
  res.end(typeof body === "string" ? body : JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      if (!chunks.length) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

function authed(req) {
  const header = req.headers["x-auth-token"];
  return header && header === TOKEN;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");

  if (req.method === "GET" && url.pathname === "/") {
    send(res, 200, fs.readFileSync(DASHBOARD_FILE, "utf8"), "text/html; charset=utf-8");
    return;
  }

  if (url.pathname.startsWith("/api/")) {
    if (!authed(req)) {
      send(res, 401, { error: "missing or invalid X-Auth-Token" });
      return;
    }

    if (req.method === "GET" && url.pathname === "/api/matches") {
      send(res, 200, { matches: readStore() });
      return;
    }

    if (req.method === "POST" && url.pathname === "/api/matches") {
      try {
        const body = await readBody(req);
        const incoming = Array.isArray(body.matches) ? body.matches : [body];
        const now = new Date().toISOString();
        const created = await withStore((matches) => {
          const made = incoming.map((m) => {
            const doc = Object.assign(
              {
                id: crypto.randomUUID(),
                status: "pending_review",
                createdAt: now,
                updatedAt: now,
              },
              m
            );
            matches.push(doc);
            return doc;
          });
          return made;
        });
        send(res, 201, { created });
      } catch (e) {
        send(res, 400, { error: "invalid JSON body" });
      }
      return;
    }

    const patchMatch = url.pathname.match(/^\/api\/matches\/([^/]+)$/);
    if (req.method === "PATCH" && patchMatch) {
      try {
        const body = await readBody(req);
        const id = decodeURIComponent(patchMatch[1]);
        const now = new Date().toISOString();
        const updated = await withStore((matches) => {
          const doc = matches.find((m) => m.id === id);
          if (!doc) return null;
          Object.assign(doc, body, { updatedAt: now });
          return doc;
        });
        if (!updated) {
          send(res, 404, { error: "no such match" });
        } else {
          send(res, 200, { match: updated });
        }
      } catch (e) {
        send(res, 400, { error: "invalid JSON body" });
      }
      return;
    }

    send(res, 404, { error: "no such route" });
    return;
  }

  send(res, 404, { error: "not found" });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`job-hunt dashboard listening on 127.0.0.1:${PORT}`);
});
