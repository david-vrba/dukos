#!/usr/bin/env bash
# select-mode.sh — choose a DukOS template + power mode and save it to config/settings.json.
# Usage: bash tools/select-mode.sh [template] [power_mode]   (run with no args for an interactive prompt)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SETTINGS="config/settings.json"

# Template -> agent set. Keep in sync with tools/cost-estimate.sh.
templates=(dev-studio marketing-engine game-studio finance-research founder-os full-studio)
power_modes=(starter standard full max)

agents_for() {
  case "$1" in
    dev-studio)        echo "builder qa research seo content growth" ;;
    marketing-engine)  echo "marketing seo copywriter content tiktok community" ;;
    game-studio)       echo "gamedev aso content community qa" ;;
    finance-research)  echo "portfolio-analyst research data competition-research" ;;
    founder-os)        echo "orchestrator research marketing content admin habit" ;;
    full-studio)       echo "orchestrator research growth competition-research marketing content copywriter seo aso tiktok community outreach builder gamedev qa data portfolio-analyst admin review assistant habit habit-morning habit-review security" ;;
    *)                 return 1 ;;
  esac
}

is_valid_template() { agents_for "$1" >/dev/null 2>&1; }
is_valid_power() {
  case "$1" in starter|standard|full|max) return 0 ;; *) return 1 ;; esac
}

# Accepts a list index (1-based) or a literal name; prints the resolved name (empty if out of range).
resolve_from() {
  local input="$1"; shift
  local -a list=("$@")
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    if [ "$input" -ge 1 ] && [ "$input" -le "${#list[@]}" ]; then
      echo "${list[$((input-1))]}"
    else
      echo ""
    fi
  else
    echo "$input"
  fi
}

usage() {
  echo "Usage: bash tools/select-mode.sh [template] [power_mode]" >&2
  echo "  templates:   ${templates[*]}" >&2
  echo "  power modes: ${power_modes[*]}" >&2
}

template="${1:-}"
power_mode="${2:-}"

# --- Interactive prompts (only for whatever wasn't passed as an arg) ------
if [ -z "$template" ]; then
  echo "Pick a template:"
  i=1; for t in "${templates[@]}"; do printf "  %d) %s\n" "$i" "$t"; i=$((i+1)); done
  printf "Template [1-%d]: " "${#templates[@]}"
  read -r reply
  template="$(resolve_from "$reply" "${templates[@]}")"
else
  template="$(resolve_from "$template" "${templates[@]}")"
fi

if [ -z "$power_mode" ]; then
  echo "Pick a power mode:"
  i=1; for p in "${power_modes[@]}"; do printf "  %d) %s\n" "$i" "$p"; i=$((i+1)); done
  printf "Power mode [1-%d]: " "${#power_modes[@]}"
  read -r reply
  power_mode="$(resolve_from "$reply" "${power_modes[@]}")"
else
  power_mode="$(resolve_from "$power_mode" "${power_modes[@]}")"
fi

# --- Validate ------------------------------------------------------------
if ! is_valid_template "$template"; then
  echo "Error: invalid template '${template}'." >&2
  usage
  exit 1
fi
if ! is_valid_power "$power_mode"; then
  echo "Error: invalid power mode '${power_mode}'." >&2
  usage
  exit 1
fi

# --- Merge into settings.json (preserve any other keys) ------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to update $SETTINGS." >&2
  exit 1
fi

python3 - "$SETTINGS" "$template" "$power_mode" <<'PY'
import json, os, sys

path, template, power_mode = sys.argv[1], sys.argv[2], sys.argv[3]

data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except (ValueError, OSError):
        data = {}
if not isinstance(data, dict):
    data = {}

# Update only the two keys we own; leave caveman_mode, projects, etc. intact.
data["template"] = template
data["power_mode"] = power_mode
data.setdefault("caveman_mode", False)

os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

# --- Report --------------------------------------------------------------
agents="$(agents_for "$template")"
echo
echo "Saved to $SETTINGS:"
echo "  template:   $template"
echo "  power_mode: $power_mode"
echo
echo "Active agents ($(echo "$agents" | wc -w | tr -d ' ')):"
for a in $agents; do echo "  - $a"; done
echo
echo "Next: bash tools/cost-estimate.sh"
