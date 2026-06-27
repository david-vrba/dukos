# /sanity-check — Claude Code Skill

> **Post-implementation audit that catches what code review misses.**

Run it after any coding session to verify your changes are production-ready. Checks security vulnerabilities, logic edge cases, missing imports, leftover artifacts, and stack-specific bugs — automatically adapting to your tech stack.

Part of the **[DukOS](https://github.com/duk-os)** skill library — the open-source Claude Code operating system.

---

## What it checks

**Universal (every run)**
- Security: hardcoded secrets, auth gaps, IDOR, SQL/command injection, XSS, crypto mistakes
- Logic: null/undefined, division by zero, float precision, off-by-one, infinite loops, date/time traps
- Performance: N+1 queries, missing indexes, O(n²) algorithms, memory leaks, render performance
- Code quality: missing awaits, leftover console.logs, merge conflict markers, missing error handling

**Stack-specific (auto-detected)**

| Stack | Extra checks |
|-------|-------------|
| Next.js | `"use client"` directives, async params, App Router patterns, metadata API, env var prefixes |
| React SPA | Rules of Hooks, useEffect deps, state mutation, key props, Vite env vars |
| Node/Express | Async error propagation, middleware order, response completion, CORS |
| Python | Async correctness, virtual env, mutable defaults, FastAPI/Django specifics |
| Go | Error handling, goroutine lifecycle, nil safety, resource cleanup |
| Frontend (any) | Loading states, error states, empty states, form UX, accessible interactions |
| DB migrations | Destructive operations, missing rollbacks, NOT NULL safety, table locks |

---

## Two modes

| Mode | Scope | When to use |
|------|-------|-------------|
| `/sanity-check` or `/sanity-check -l` | **LOW** — recently changed files only | After every coding session |
| `/sanity-check -h` | **HIGH** — full codebase | Before a PR, before a deploy |

---

## Install

### Step 1 — Copy the skill files

**macOS / Linux:**
```bash
mkdir -p ~/.claude/skills/sanity-check-stacks
cp sanity-check.md ~/.claude/skills/
cp sanity-check-stacks/*.md ~/.claude/skills/sanity-check-stacks/
```

**Windows (Git Bash):**
```bash
mkdir -p ~/.claude/skills/sanity-check-stacks
cp sanity-check.md ~/.claude/skills/
cp sanity-check-stacks/*.md ~/.claude/skills/sanity-check-stacks/
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\sanity-check-stacks"
Copy-Item sanity-check.md "$env:USERPROFILE\.claude\skills\"
Copy-Item sanity-check-stacks\*.md "$env:USERPROFILE\.claude\skills\sanity-check-stacks\"
```

### Step 2 — Use it

```
/sanity-check       # quick check (changed files only)
/sanity-check -l    # same as above — explicit LOW mode
/sanity-check -h    # deep check (full codebase)
```

---

## Example output

```
SANITY CHECK — LOW — WARN
Next.js | Goal: add Stripe webhook handler

🟡 Warnings
  1. Missing error boundary for async component [app/webhooks/route.ts:45]
     → Add try/catch around stripe.constructEvent() call
  2. console.log left in production code [app/webhooks/route.ts:67]
     → Remove before shipping

Tests: tsc PASS
Verdict: READY (after fixing warnings)
Auto-fixable: 2  |  Needs your call: none
```

---

## Part of DukOS

This skill is part of **[DukOS](https://github.com/duk-os)** — a shift-based AI agent operating system for Claude Code. Autonomous operations on a schedule.

> Built by [@dvrbcode](https://github.com/dvrbcode)

**Other DukOS skills:**
- [`/orient`](https://github.com/duk-os/orient) — get oriented in any codebase in 60 seconds
- [`/code-review`](https://github.com/duk-os/code-review) — multi-agent PR review with confidence scoring
