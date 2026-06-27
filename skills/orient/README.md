# /orient — Claude Code Skill

> **Get oriented in any codebase in under 60 seconds.**

Drop into a project you haven't touched in weeks and instantly get:
- What the project is + its stack
- Recent git activity and uncommitted work
- The 5–8 files/dirs that actually matter
- Loose ends (TODOs, missing tests, half-done work)

Part of the **[DukOS](https://github.com/duk-os)** skill library — the open-source Claude Code operating system.

---

## Install

### Option A — Project-level (works in one repo)

```bash
mkdir -p .claude/commands
curl -o .claude/commands/orient.md \
  https://raw.githubusercontent.com/duk-os/orient/main/.claude/commands/orient.md
```

### Option B — Global (works everywhere)

```bash
# macOS / Linux
mkdir -p ~/.claude/commands
curl -o ~/.claude/commands/orient.md \
  https://raw.githubusercontent.com/duk-os/orient/main/.claude/commands/orient.md

# Windows (PowerShell)
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/duk-os/orient/main/.claude/commands/orient.md" `
  -OutFile "$env:USERPROFILE\.claude\commands\orient.md"
```

---

## Usage

```
/orient
/orient where's the auth code
/orient how does the build pipeline work
```

---

## Example output

```
## orient

**What this is**
Next.js 15 SaaS app — subscription management + user dashboard.
Stack: Next.js / TypeScript / Prisma / Postgres / Stripe / Vercel.

**Where things stand**
Last commit (2 days ago): "add Stripe webhook handler"
Uncommitted: 2 modified files (app/api/webhooks/stripe/route.ts, prisma/schema.prisma)

**Where to start**
- app/          → Next.js App Router (routes, layouts, server components)
- app/api/      → API routes (auth, payments, webhooks)
- lib/          → Shared utilities (db.ts, auth.ts, stripe.ts)
- prisma/       → DB schema + migrations
- components/   → UI components

**Loose ends**
- 3 TODOs in app/dashboard/ (feature flags not wired up)
- No tests (no test runner configured)
```

---

## Part of DukOS

This skill is part of **[DukOS](https://github.com/duk-os)** — a shift-based AI agent operating system for Claude Code. Autonomous operations on a schedule.

> Built by [@dvrbcode](https://github.com/dvrbcode)
