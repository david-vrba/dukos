# Task Board

**Orchestrator-owned.** Only the **orchestrator** writes to this file — it owns the backlog,
assigns priorities and shifts, and marks tasks DONE. Working agents **read** their own rows
(via grep, per `_shared-rules.md`) and never edit the board. To request new work, a working
agent appends a line to `tasks/requests.md`; the orchestrator processes those at handoff and
adds real tasks here.

Per-task specs (when a task needs more than one line) live in `tasks/details/[id].md` and are
loaded just-in-time by the agent that picks the task up.

Priority: **CRITICAL** > **HIGH** > **MEDIUM** > **LOW**
Status: `queued` · `in-progress` · `blocked` · `DONE`
Shift: `NIGHT1` · `HANDOFF` · `NIGHT2` · `MORNING` · `BURST` · `DAYTIME` · `STRATEGY` · `AFTERNOON_PUSH` · `EVENING`

> The rows below are **examples** to show the format. Replace them with your own tasks
> (or let the orchestrator generate them on its first shift).

| ID | Priority | Shift | Agent | Project | Task | Status |
|---|---|---|---|---|---|---|
| T-001 | HIGH | STRATEGY | research | my-saas | Competitor teardown of the 3 closest SaaS rivals — pricing, positioning, gaps | queued |
| T-002 | MEDIUM | AFTERNOON_PUSH | content | my-brand | Draft a 5-post launch thread for the brand's next release | queued |
| T-003 | HIGH | MORNING | qa | my-game | Regression pass on the latest build — verify the level-load fix, log any breakage | queued |
| T-004 | LOW | BURST | seo | my-saas | On-page SEO audit of the marketing site — titles, schema, internal links | queued |
