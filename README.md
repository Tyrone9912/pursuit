# Pursuit

Pursuit is an AI-assisted job search system that I built for my own job hunt. It has two parts:

1. **Pursuit (macOS app):** a native SwiftUI app. You drop in a job description, and it researches the company, tailors a cover letter to your own templates, drafts cold outreach, and logs the application to a tracker.
2. **Job hunt agent:** a headless agent that runs on a schedule. Every two hours it searches compliant job boards, drafts a fit summary and a cover-letter opening for each new match, and queues everything on a dashboard for you to approve from your phone. It fills in the applications you approve and **always stops one click before submitting**.

I designed both with the AI proposing and a human deciding. Nothing gets sent without my approval.

---

## Why I built it

Job searching is repetitive, high-volume work: reading postings, judging fit, and rewriting the same material for each role. That's exactly where AI helps. It's also where careless automation hurts you, with mass-applying, invented details, and bots scraping sites that forbid it. So I set out to automate the tedious parts and keep judgment and the final action with a person.

## Pursuit, the macOS app

| | |
|---|---|
| **Platform** | macOS 14+, SwiftUI, Swift 6, SwiftData |
| **AI backend** | Claude API as the primary model, with automatic fallback to a local Ollama model when the API can't be reached |
| **Flow** | Drop a JD → parse (regex first, LLM fallback) → research → cover letter → outreach → tracker |

**Design decisions worth noting**

- **One model manager, two backends** (`Services/ModelManager.swift`). The rest of the app calls a single interface. If Claude is unavailable, it switches to a local model, so the app keeps working offline.
- **Deterministic parsing first, LLM second** (`Services/JDParser.swift`). Salary, company, and role are pulled with regex where possible. The model only handles the cases regex can't, and it must return strict JSON that the app validates (`Models/JSONExtraction.swift`).
- **Grounded in your own documents.** Cover letters and outreach are built from the templates you import, such as your resume and cover-letter template (`Services/TemplateLoader.swift`). Multiple profiles are supported.
- **Plain-language output.** Generated text is cleaned of AI-sounding phrasing before you see it (`Models/PlainLanguage.swift`).
- **Missing salary is flagged, not guessed.** When a posting has no salary, the UI shows a visible "Salary not listed" flag.
- **No secrets in code.** The API key is read from the `ANTHROPIC_API_KEY` environment variable or from user defaults.

**Build**

```bash
brew install xcodegen
xcodegen generate        # creates Pursuit.xcodeproj from project.yml
open Pursuit.xcodeproj
export ANTHROPIC_API_KEY=...   # optional; without it, Pursuit uses local Ollama
```

## Job hunt agent

See [`job-hunt-agent/README.md`](job-hunt-agent/README.md) for setup and operation.

**Architecture**

```
launchd (every 2h, 8am–8pm)
   └─ run-sweep.sh ──► Claude Code, headless (`claude -p sweep-instructions.md`)
                          ├─ reads preferences.json + your resume
                          ├─ searches Greenhouse / Lever / Ashby / career pages
                          ├─ drafts fit summary + cover-letter opening
                          ├─ fills APPROVED applications via browser automation (never submits)
                          └─ POSTs to ──► server.js (localhost:8787, token-auth, JSON store)
                                               └─ dashboard.html ◄── phone via Tailscale
                                                                      + ntfy push alert
```

**Guardrails, written into the agent's instructions** (`sweep-instructions.md`)

- It never clicks a final Submit, Apply, or Send button. The human always makes the last click.
- It only fills applications that a person explicitly approved on the dashboard.
- It only uses compliant sources: company career pages, Greenhouse, Lever, Ashby, and general web search. It never scrapes or automates LinkedIn or Indeed.
- It never invents personal details that aren't in the resume.
- It caps new matches per run and deduplicates by source URL, so it doesn't flood the queue or hammer job sites.
- The dashboard server binds to localhost only and requires a token. Remote access goes through a private Tailscale network, never the public internet.
- A single write queue serializes updates to the JSON store, so the agent and the dashboard can't corrupt each other's writes.

## Tech

Swift 6 · SwiftUI · SwiftData · XcodeGen · Claude API · Ollama · Claude Code (headless) · Node.js · launchd · Tailscale · ntfy

---

Built by **Tyrone Gibson**, an IT manager moving into applied AI, with AI-assisted development. I wrote the specs and change requests, then reviewed and tested the results.
