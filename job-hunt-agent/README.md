# Job hunt agent

An automated job search that runs on this Mac, finds matching openings,
drafts application material, and queues everything for your approval from
your phone. It's a companion to Pursuit — separate code, doesn't touch
Pursuit's app data.

Two always-on pieces, both installed as launchd services (they survive
reboots and don't need Terminal or Claude Code open):

- **`com.tyrone.pursuit-jobhunt-server`** — a small local web server
  (`server.js`) that serves the dashboard and holds the data (`data/matches.json`).
  Runs continuously, restarts itself if it crashes.
- **`com.tyrone.pursuit-jobhunt`** — the sweep. Fires every 2 hours,
  8am–8pm, and runs `sweep-instructions.md` as a one-shot headless Claude
  Code session.

## First-time setup

1. `cp preferences.example.json preferences.json` and edit roles, location, salary floor, and industry focus.
2. Put your resume in this folder as `resume.docx`.
3. Create an access token: `openssl rand -hex 16 > server.token`
4. Choose a hard-to-guess ntfy topic name and replace `<your-ntfy-topic>` in `sweep-instructions.md`.
5. In both `.plist` files, replace `YOUR_USERNAME` with your macOS username, copy them to `~/Library/LaunchAgents/`, and `launchctl load` each one.

`preferences.json`, `resume.docx`, `server.token`, `data/`, and `logs/` are git-ignored, so your personal data stays on your machine.

## What the sweep does, every run

1. Fills in any application you approved on the dashboard, using browser
   automation — stops right before the final submit button, always.
2. Searches Greenhouse, Lever, Ashby job boards and general web search
   (never LinkedIn/Indeed) for new openings matching `preferences.json`.
3. Drafts a fit summary and a cover-letter opening for each new match.
4. Adds new matches to the dashboard and sends a push notification if
   anything changed.

You never get auto-applied for. The agent stops one click short every time.

## Dashboard

The dashboard is served locally by `server.js`, not hosted on claude.ai — it
needed to be a plain local server so the headless sweep script could read
and write it directly (Claude's own Artifact tools turned out to only work
in interactive sessions, not headless ones).

**On this Mac**: http://127.0.0.1:8787/?token=<token from server.token>

**From your phone**: needs Tailscale (see below), then:
http://<this-mac's-tailscale-name>:8787/?token=<token from server.token>

The token is in `server.token` in this folder. Visiting the URL once saves
it in your browser, so you only need the `?token=...` link the first time.

Tabs: Pending review, Approved, Ready to submit, History. Approve or reject
a match right from the card — that write happens immediately and the next
sweep picks it up.

## Setting up phone access (Tailscale)

Tailscale creates a private network between just your own devices — the
dashboard is never exposed to the public internet.

1. Install Tailscale on this Mac: `brew install --cask tailscale`, then open
   it from Applications and sign in.
2. Install the Tailscale app on your phone (App Store / Play Store) and sign
   in with the same account.
3. On the Mac, run `tailscale serve --bg 8787` — this makes the dashboard
   reachable from your other Tailscale devices without the server itself
   listening on any network interface (it stays bound to localhost;
   Tailscale proxies to it).
4. Find this Mac's Tailscale address: `tailscale status` (or the menu bar
   app). It looks like `mac-name.tailnet-name.ts.net`.
5. On your phone, open `https://<that address>/?token=<token from server.token>`.

## Notifications

Push notifications go to ntfy.sh, topic `<your-ntfy-topic>`. To
receive them on your phone:

1. Install the free **ntfy** app (App Store / Play Store), or just use
   https://ntfy.sh/<your-ntfy-topic> in a browser.
2. Subscribe to topic `<your-ntfy-topic>`.

The topic name is unguessable but not secret-secret — anyone who has it
could subscribe. Don't publish it anywhere public.

## Editing your search

Edit `preferences.json` any time — roles, locations, salary floor, industry
focus, how many new matches per run. Changes apply on the next sweep, no
restart needed.

To update your resume, replace `resume.docx` in this folder with a new export
(keep the file's real format/extension — a mislabeled file broke the first
test run).

## Operating it

- **Logs**: `logs/sweep.log` (what each sweep did), `logs/launchd.out.log` /
  `logs/launchd.err.log` (raw sweep process output), `logs/server.out.log` /
  `logs/server.err.log` (dashboard server output).
- **Run a sweep manually**: `./run-sweep.sh` (useful for testing without
  waiting for the schedule).
- **Check the server is up**: `curl http://127.0.0.1:8787/` should return
  HTML. `launchctl list | grep pursuit-jobhunt` should show both services.
- **Pause the sweep** (leaves the dashboard server running):
  `launchctl unload ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt.plist`
- **Resume it**:
  `launchctl load ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt.plist`
- **Stop the dashboard server too**:
  `launchctl unload ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt-server.plist`
- **Uninstall entirely**:
  ```
  launchctl unload ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt.plist
  launchctl unload ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt-server.plist
  rm ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt.plist
  rm ~/Library/LaunchAgents/com.tyrone.pursuit-jobhunt-server.plist
  ```
- **Change the sweep schedule**: edit `StartCalendarInterval` in
  `com.tyrone.pursuit-jobhunt.plist`, then re-copy it to
  `~/Library/LaunchAgents/` and reload (unload, then load).

## Known limitations

- **The apply-fill step needs Chrome open** with the "Claude in Chrome"
  extension connected. If Chrome isn't running when a sweep fires, that
  run just skips the apply step and tries again next time — discovery and
  drafting still work fine either way.
- **The Mac needs to be awake** for a sweep to fire on schedule, and for the
  dashboard to be reachable at all (it's this Mac's own server). A missed
  interval while asleep isn't made up; it just runs at the next scheduled
  time the Mac is awake.
- The first time browser automation runs, macOS may prompt for
  accessibility/automation permissions for Chrome — approve that prompt
  once and it won't ask again.
- This only ever applies through compliant sources (company career pages,
  Greenhouse, Lever, Ashby, general search). It will not touch LinkedIn or
  Indeed.
