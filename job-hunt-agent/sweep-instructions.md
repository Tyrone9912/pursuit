# Job hunt sweep

You are running unattended, triggered by a macOS launchd schedule (not an
interactive session). Nobody is watching this run — do not ask questions, do
not wait for confirmation. Work through the steps below in order, then stop.
Keep total tool calls reasonable; this runs again in 2 hours.

Working directory: `~/Developer/Pursuit/job-hunt-agent/`
Dashboard API: `http://127.0.0.1:8787` (local server, always running — see
Step 2 for the auth token)
ntfy topic: `<your-ntfy-topic>` (POST to `https://ntfy.sh/<your-ntfy-topic>`)

## Hard rules — never violate these

- **Never click a final "Submit," "Apply," or "Send application" button.** Fill
  forms, then stop and screenshot. The human always makes the last click.
- **Only use compliant job sources**: company career pages, Greenhouse
  (`boards.greenhouse.io`, `boards-api.greenhouse.io`), Lever
  (`jobs.lever.co`, `api.lever.co`), Ashby (`jobs.ashbyhq.com`), and general
  web search. Never scrape or auto-interact with LinkedIn or Indeed.
- **Only fill applications for matches with status `approved`**. Never fill
  or submit anything the person hasn't explicitly approved on the dashboard.
- **Cap new matches at `max_new_matches_per_run` from preferences.json**
  (currently 8) — don't flood the queue or hammer job sites.
- Always dedupe against existing matches' `sourceUrl` before treating a
  posting as new (see Step 2).

## Step 1 — Read inputs

1. Read `preferences.json` in this directory for target roles, seniority,
   location rules, salary floor, employment type, industry focus, and
   `max_new_matches_per_run`.
2. Read `resume.docx` in this directory for the candidate's actual background,
   skills, and work history — use this to judge fit and to draft content in
   his real voice, not generic boilerplate.
3. Read `server.token` in this directory — its contents are the value for
   the `X-Auth-Token` header on every API call below.

## Step 2 — Read current dashboard state

```bash
curl -s -H "X-Auth-Token: $(cat server.token)" http://127.0.0.1:8787/api/matches
```

This returns `{"matches": [...]}`, the full current list. From it, derive:

- **Seen URLs**: the `sourceUrl` of every match already in the list. Skip any
  posting you find in Step 4 whose canonical URL matches one of these.
- **Approved, not yet filled**: matches with `status == "approved"` — these
  are waiting on you to fill in Step 3.

If the request fails (connection refused, non-200), the local server isn't
running. Note this in the Step 8 log line and skip straight to Step 8 — there
is nothing else this run can do without it.

## Step 3 — Apply step (handle approvals first)

For each `approved` match from Step 2:

1. Load the browser automation tools if not already loaded: ToolSearch
   `"select:mcp__claude-in-chrome__tabs_context_mcp,mcp__claude-in-chrome__navigate,mcp__claude-in-chrome__computer,mcp__claude-in-chrome__read_page,mcp__claude-in-chrome__tabs_create_mcp,mcp__claude-in-chrome__form_input,mcp__claude-in-chrome__tabs_close_mcp"`.
2. If Chrome isn't reachable or the extension isn't connected, **skip the
   apply step entirely for this run** (leave these matches `approved`, try
   again next sweep) and continue to Step 4 — don't fail the whole run over
   this.
3. Open the match's `sourceUrl` in a new tab. Fill the application form using
   the resume and the match's drafted `coverLetterOpening` where a cover
   letter or "why this role" field exists. Use the candidate's real contact
   details only if already visible in the resume text — never invent
   personal information (phone, address) that isn't in the resume; leave
   those fields for the person to fill in themselves and note it.
4. **Stop immediately before the final submit action.** Do not click it.
5. Update that match via:
   ```bash
   curl -s -X PATCH -H "X-Auth-Token: $(cat server.token)" -H "Content-Type: application/json" \
     -d '{"status":"ready_to_submit","screenshotNote":"<one sentence: what is filled in, what is left, which Chrome tab>"}' \
     http://127.0.0.1:8787/api/matches/<match id>
   ```
6. Close extra tabs you opened once done with each one.

## Step 4 — Discovery step

1. Search the compliant sources for openings matching `preferences.json`:
   target roles, mid/senior level, remote or DC-hybrid, full-time, $130k+
   floor. Weight explicit bonus fit for Big Law / legal IT / Apple-shop IT
   environments / tech companies, per `industry_focus.prioritize`.
   - Try Greenhouse/Lever/Ashby job-board search first
     (e.g. `site:boards.greenhouse.io "IT Manager"`,
     `site:jobs.lever.co "Helpdesk Manager"`, `site:jobs.ashbyhq.com`), then
     general web search for the same role titles with "remote" or
     "Washington DC". If querying Ashby's API directly with curl, send a
     browser-style `User-Agent` header — it blocks bare requests otherwise.
2. For each candidate posting, get its canonical URL and check it against the
   seen-URL set from Step 2. Skip anything already seen.
3. Stop once you have `max_new_matches_per_run` new qualifying matches (or
   run out of good candidates — don't force weak matches to hit the cap).
4. For each new match, judge fit against the resume and preferences. Reject
   anything that doesn't actually meet the hard filters (salary floor,
   location, employment type) — quality over quantity.

## Step 5 — Draft content for new matches

For each new qualifying match, write:

- `fitNotes`: 2-3 sentences, plain language, no em dashes, explaining
  specifically why this role fits — grounded in real resume details, not
  generic praise.
- `coverLetterOpening`: a short first-person opening paragraph (3-5
  sentences) in a direct, confident voice, plain language, no em dashes,
  referencing something specific about the role or company. This is a draft
  the person can edit before it's used, not a finished letter.

## Step 6 — Write results to the dashboard

For each new match:

```bash
curl -s -X POST -H "X-Auth-Token: $(cat server.token)" -H "Content-Type: application/json" \
  -d '{
    "company": "...",
    "role": "...",
    "location": "...",
    "salary": "... or null",
    "source": "greenhouse | lever | ashby | web",
    "sourceUrl": "...",
    "fitNotes": "...",
    "coverLetterOpening": "..."
  }' \
  http://127.0.0.1:8787/api/matches
```

(`status`, `createdAt`, `updatedAt`, and `id` are set automatically by the
server — don't include them.) You can POST `{"matches": [...]}` with an array
to create several in one call instead of one request per match.

## Step 7 — Notify

If Step 3 produced any `ready_to_submit` items, or Step 6 added any new
matches, send exactly one summary notification:

```bash
curl -s -d "N new matches, M ready to submit. Check your dashboard." \
  https://ntfy.sh/<your-ntfy-topic>
```

Fill in the real counts. If nothing changed this run, send nothing.

## Step 8 — Log

Print one final line summarizing the run, e.g.:
`[run] N new matches queued, M approved items filled, K skipped (chrome
unavailable), 0 errors.` This gets captured in `logs/sweep.log` by the
wrapper script.
