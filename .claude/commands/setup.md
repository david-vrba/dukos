---
description: First-time setup and onboarding for DukOS — checks your tools, configures .env, helps pick a template, previews cost, and walks you through your first shift. Interactive and safe.
allowed-tools: Bash, Read, Edit, Glob, Grep, AskUserQuestion
---

# DukOS — Setup & Onboarding

You are onboarding a new user setting up DukOS for the first time in THIS repository.
Be warm, concise, and do the work for them — run the commands yourself and react to the
output; don't just print instructions. **Never** spend money or launch agents without
explicit confirmation, and **never** read or print a secret value.

Go step by step. After each step, say in one line what happened, then continue.

## 1. Orient (brief)
In two sentences, tell them what DukOS is: a team of scheduled AI agents that run a solo
founder's business operations (research, marketing, content, growth, outreach, admin) on
Claude Code, unattended, and report back each morning. Point them at the README for the
full map, then start.

## 2. Check tools + scaffold
Run:
```bash
bash tools/setup.sh
```
It verifies required tools (claude, git, python3), creates runtime directories, and seeds
`.env`. If it reports a missing required tool, stop, give the install link, and re-run after
they install it. Don't continue until it exits cleanly.

## 3. API key or subscription
- If they have an Anthropic API key, help them put it in `.env` as `ANTHROPIC_API_KEY=...`
  (edit the file for them if they paste it — never echo the value back, never print it).
- If they're already signed into a Claude subscription via the Claude Code CLI, tell them
  they can leave `ANTHROPIC_API_KEY` blank.

`.env` is gitignored — confirm that, and never display its contents.

## 4. Pick a template + power mode
Ask what they do (solo dev / marketer / game dev / trader / founder-of-everything) and which
power mode fits their budget (Starter / Standard / Full / Max — see the README cost table).
Then run:
```bash
bash tools/select-mode.sh
```
Help them choose, or set their pick in `config/settings.json`.

## 5. Preview cost FIRST
Run:
```bash
bash tools/cost-estimate.sh
```
Show the rough monthly forecast. Make sure they understand DukOS runs on their own API key
and they pay for what they run — heavy configs can cost $500+/month. Tell them to set a
billing limit in the Anthropic Console. Point them at `DISCLAIMER.md`.

## 6. First shift (only with explicit yes)
Explain that launching a shift starts real agents that read/modify files and spend API
tokens. Ask for explicit confirmation. Only if they say yes:
```bash
bash run.sh
```
Otherwise, tell them the command to run when they're ready.

## 7. Scheduling (explain)
The real value is running shifts on a schedule. Point them at Windows Task Scheduler or cron
to run `bash run.sh` on the schedule in the README's "Shift schedule" table. Offer to help
write a scheduled task.

## 8. Wrap up
Summarize what's configured, where outputs land (`reports/`, the morning briefing), and the
other built-in skills: `/orient` (get oriented in any codebase) and `/sanity-check` (audit
recent changes). Point them at `CONTRIBUTING.md` to add their own agent.

Throughout: prefer doing the safe steps for them, never print secret values, and always
confirm before anything that costs money or launches agents.
