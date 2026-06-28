---
description: Drop into a project you haven't touched in a while and get oriented fast — what it is, the stack, entry points, recent activity, and where to start. For context-switching between many repos.
argument-hint: [optional: a specific question, e.g. "where's the auth code"]
allowed-tools: Bash, Read, Glob, Grep
---

Rapidly map the CURRENT project so the user can start working without rereading everything. Assume they've been away for weeks. Be fast and concrete; do not modify anything.

## Gather (parallelize where possible)
1. **What it is + stack** — read the README and the manifest (package.json / pyproject.toml / go.mod / Cargo.toml / etc.). Identify framework, language, and package manager (check the lockfile).
2. **Recent activity** — only if this is a git repo (else skip): `git log --oneline -15` and `git status` (what was last worked on; anything uncommitted or stashed).
3. **Shape** — top-level layout and the *real* entry points (main file, routes, app root, config). Name the 5–8 places that matter — don't dump the whole tree.
4. **Last known state** — read this project's `session_state_*.md` / `compact_checkpoint.md` from its memory folder if present (what the user was last doing here).
5. **Loose ends** — count TODO/FIXME/HACK markers; note whether tests and build/CI config exist.

## Report — short and structured
- **What this is** — 1–2 sentences + a one-line stack summary.
- **Where things stand** — recent commits in plain words, uncommitted work, and the last session state.
- **Where to start** — the key files/dirs mapped to what they do.
- **Loose ends** — TODOs, missing/failing tests, anything half-done.

If the user asked a specific question in the argument, **answer that first**, then give the rest briefly.

Keep it tight — this is orientation, not an audit. If something looks broken, flag it; don't fix it unless asked.
