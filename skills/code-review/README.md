# /code-review — Claude Code Skill

> **Multi-agent PR review with confidence scoring. Only flags issues it's 80%+ certain about.**

Run it on any GitHub pull request to get an automated code review from 5 parallel reviewers. Each issue is confidence-scored by a separate judge agent — low-confidence findings are filtered out automatically. Posts results as inline PR comments via `gh`.

Part of the **[DukOS](https://github.com/duk-os)** skill library — the open-source Claude Code operating system.

---

## What it does

Runs **5 parallel review agents**, each with a different lens:

| Agent | Lens |
|-------|------|
| #1 — CLAUDE.md Auditor | Does the change follow the project's own coding guidelines? |
| #2 — Bug Scanner | Obvious bugs in the diff — no extra context, fast and focused |
| #3 — History Reader | Bugs in light of git blame and prior commits to these files |
| #4 — PR History | Comments on past PRs that touched the same files |
| #5 — Comment Auditor | Does the change comply with code comments and inline docs? |

Each finding is then **confidence-scored 0–100** by a judge agent. Issues below 80 are filtered out — you only see what it's confident about.

---

## Requirements

- GitHub CLI (`gh`) installed and authenticated: `gh auth login`
- Claude Code with `--dangerously-skip-permissions` or appropriate tool permissions

---

## Install

### macOS / Linux
```bash
mkdir -p ~/.claude/commands
curl -o ~/.claude/commands/code-review.md \
  https://raw.githubusercontent.com/duk-os/code-review/main/.claude/commands/code-review.md
```

### Windows (PowerShell)
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/duk-os/code-review/main/.claude/commands/code-review.md" `
  -OutFile "$env:USERPROFILE\.claude\commands\code-review.md"
```

---

## Usage

```bash
# Run on a specific PR by number (in the repo directory)
/code-review 42

# Run on the current branch's open PR
/code-review
```

---

## Example output (posted as PR comment)

```
### Code review

Found 2 issues:

1. Missing error boundary for async component (CLAUDE.md says "wrap async server components in Suspense")

https://github.com/org/repo/blob/abc123.../app/dashboard/page.tsx#L45-L52

2. SQL query constructed via string interpolation — SQL injection risk

https://github.com/org/repo/blob/abc123.../lib/db/queries.ts#L78-L82

🤖 Generated with Claude Code
```

---

## Part of DukOS

This skill is part of **[DukOS](https://github.com/duk-os)** — a shift-based AI agent operating system for Claude Code. Autonomous operations on a schedule.

> Built by [@dvrbcode](https://github.com/dvrbcode)

**Other DukOS skills:**
- [`/sanity-check`](https://github.com/duk-os/sanity-check) — post-implementation audit for security, logic, and stack-specific bugs
- [`/orient`](https://github.com/duk-os/orient) — get oriented in any codebase in 60 seconds
