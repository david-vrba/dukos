#!/usr/bin/env bash
# cost-estimate.sh — rough monthly API cost estimate from config/settings.json.
# Prints a transparent low–high USD range with every assumption stated. Estimate only, never a quote.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SETTINGS="config/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo "No $SETTINGS found. Run: bash tools/select-mode.sh" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required for cost-estimate." >&2
  exit 1
fi

python3 - "$SETTINGS" <<'PY'
import json, sys

with open(sys.argv[1]) as f:
    settings = json.load(f)

# --- Template -> agent set (keep in sync with tools/select-mode.sh) ------
TEMPLATE_AGENTS = {
    "dev-studio":       ["builder", "qa", "research", "seo", "content", "growth"],
    "marketing-engine": ["marketing", "seo", "copywriter", "content", "tiktok", "community"],
    "game-studio":      ["gamedev", "aso", "content", "community", "qa"],
    "finance-research": ["portfolio-analyst", "research", "data", "competition-research"],
    "founder-os":       ["orchestrator", "research", "marketing", "content", "admin", "habit"],
    "full-studio":      ["orchestrator", "research", "growth", "competition-research", "marketing",
                         "content", "copywriter", "seo", "aso", "tiktok", "community", "outreach",
                         "builder", "gamedev", "qa", "data", "portfolio-analyst", "admin", "review",
                         "assistant", "habit", "habit-morning", "habit-review", "security"],
}

# --- Public per-MTok prices (USD). These are ESTIMATES and change over time;
#     verify the current numbers with your provider before relying on them. ---
PRICES = {  # tier: (input $/MTok, output $/MTok)
    "haiku":  (1.0,  5.0),    # Claude Haiku  tier
    "sonnet": (3.0, 15.0),    # Claude Sonnet tier
    "opus":   (5.0, 25.0),    # Claude Opus   tier
}

# --- Power mode -> model tier + sessions per agent per day ----------------
POWER = {  # mode: (tier, sessions_per_agent_per_day)
    "starter":  ("haiku",  1),
    "standard": ("sonnet", 2),
    "full":     ("sonnet", 3),
    "max":      ("opus",   4),
}

# --- Per-session token assumptions (ESTIMATES) ----------------------------
# An agent session re-sends its context across the agentic loop, so the real
# billed token count is much larger than the raw prompt. These bracket a
# light vs a heavy session (input + output combined).
TOKENS_PER_SESSION_LOW  = 40_000
TOKENS_PER_SESSION_HIGH = 200_000

# Assumed input/output split for a read-heavy agent (80% in / 20% out).
INPUT_SHARE  = 0.8
OUTPUT_SHARE = 0.2

DAYS = 30

template   = settings.get("template", "founder-os")
power_mode = settings.get("power_mode", "standard")
projects   = settings.get("projects") or []

if template not in TEMPLATE_AGENTS:
    print(f"Unknown template '{template}'. Run tools/select-mode.sh.", file=sys.stderr)
    sys.exit(1)
if power_mode not in POWER:
    print(f"Unknown power_mode '{power_mode}'. Run tools/select-mode.sh.", file=sys.stderr)
    sys.exit(1)

tier, sessions_per_day = POWER[power_mode]
in_price, out_price = PRICES[tier]
blended = in_price * INPUT_SHARE + out_price * OUTPUT_SHARE  # $/MTok

# Agent count: sum the per-project templates when any are configured,
# otherwise use the top-level template.
breakdown = None
if projects:
    breakdown = []
    agent_count = 0
    for p in projects:
        ptpl = p.get("template", template)
        n = len(TEMPLATE_AGENTS.get(ptpl, []))
        agent_count += n
        breakdown.append((p.get("id", "?"), ptpl, n))
else:
    agent_count = len(TEMPLATE_AGENTS[template])

sessions_month = agent_count * sessions_per_day * DAYS

def cost(tokens_per_session):
    return sessions_month * tokens_per_session / 1_000_000 * blended

low  = cost(TOKENS_PER_SESSION_LOW)
high = cost(TOKENS_PER_SESSION_HIGH)

print()
print("DukOS — rough monthly cost estimate")
print("===================================")
print()
print("Configuration:")
print(f"  template:    {template}")
print(f"  power_mode:  {power_mode}")
if breakdown:
    print(f"  projects:    {len(breakdown)} (agent count summed across project teams)")
    for pid, ptpl, n in breakdown:
        print(f"     - {pid}: {ptpl} ({n} agents)")
print()
print("Assumptions (all rough — edit the constants in this script to refine):")
print(f"  model tier:           {tier}  (${in_price:.0f}/MTok in, ${out_price:.0f}/MTok out)")
print(f"  blended price:        ${blended:.2f}/MTok  ({int(INPUT_SHARE*100)}% in / {int(OUTPUT_SHARE*100)}% out)")
print(f"  active agents:        {agent_count}")
print(f"  sessions/agent/day:   {sessions_per_day}")
print(f"  days/month:           {DAYS}")
print(f"  tokens/session:       {TOKENS_PER_SESSION_LOW:,} (light) ... {TOKENS_PER_SESSION_HIGH:,} (heavy)")
print()
print("Arithmetic:")
print(f"  sessions/month = {agent_count} agents x {sessions_per_day}/day x {DAYS} days = {sessions_month:,}")
print(f"  cost = sessions/month x tokens/session / 1,000,000 x ${blended:.2f}/MTok")
print()
print(f"  >>> Estimated range: ${low:,.0f} - ${high:,.0f} / month <<<")
print()
print("This is a ROUGH ESTIMATE, not a quote. Real cost depends on your actual")
print("token use, prompt caching (cache reads cost ~0.1x), how often shifts run,")
print("and current model pricing. A Claude subscription may cover this usage at")
print("no per-token cost. Always watch your provider's billing dashboard.")
print()
PY
