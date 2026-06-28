#!/usr/bin/env bash
# setup.sh — one-time environment setup for DukOS.
# Verifies required tools, creates runtime directories, and seeds .env. Safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }

echo
echo "DukOS setup"
echo "==========="
echo

# --- Required tools ------------------------------------------------------
# claude + git are hard requirements; node + python3 are recommended only.
missing_hard=0

check_required() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$2 found"
  else
    err "$2 NOT found — required"
    missing_hard=1
  fi
}

check_optional() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$2 found"
  else
    warn "$2 not found — $3"
  fi
}

echo "Checking tools..."
check_required claude   "Claude Code CLI (claude)"
check_required git      "git"
check_optional node     "Node.js (node)"     "only needed by a few optional skills"
check_required python3  "Python 3 (python3)"
echo

if [ "$missing_hard" -ne 0 ]; then
  err "Install the missing required tools, then re-run: bash tools/setup.sh"
  echo "      Claude Code:  https://claude.ai/code"
  echo "      git:          https://git-scm.com/downloads"
  echo "      Python 3:     https://www.python.org/downloads/"
  exit 1
fi

# --- Runtime directories -------------------------------------------------
echo "Creating runtime directories..."
for d in logs checkpoint handoff tasks reports projects config; do
  if [ -d "$d" ]; then
    info "$d/ exists"
  else
    mkdir -p "$d"
    ok "created $d/"
  fi
done
echo

# --- .env ----------------------------------------------------------------
echo "Checking environment file..."
if [ -f .env ]; then
  info ".env already exists — leaving it untouched"
elif [ -f config/.env.example ]; then
  cp config/.env.example .env
  ok "created .env from config/.env.example"
  warn "edit .env before launching (see the comments in the file)"
else
  warn "config/.env.example is missing — cannot seed .env"
fi
echo

# --- Next steps ----------------------------------------------------------
echo "Setup complete. Next steps:"
echo "  1. Edit .env            — add ANTHROPIC_API_KEY (or leave blank if signed into a Claude subscription)"
echo "  2. bash tools/select-mode.sh    — pick a template + power mode"
echo "  3. bash tools/cost-estimate.sh  — preview a rough monthly cost"
echo "  4. bash run.sh          — launch a shift"
echo
