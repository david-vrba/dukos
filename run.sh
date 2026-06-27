#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  DukOS — Studio Launch Script
#  Run manually:    Open Git Bash → bash run.sh
#  Run scheduled:   echo '1' | bash run.sh
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

# Source .env if present — makes ANTHROPIC_API_KEY, MESSAGING_BOT_TOKEN,
# MESSAGING_CHAT_ID, OWNER_TRUST_TOKEN, PROJECTS_DIR, etc. available to all
# agent subprocesses.
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
fi

# Billing safety: never let a metered ANTHROPIC_API_KEY (from .env or the ambient
# environment) reach the `claude --print` agent subprocesses — that would silently
# move the entire subscription fleet onto the paid API. The CLI authenticates via the
# subscription (OAuth in ~/.claude), not this key. count-tokens.sh falls back to a
# local estimate when the key is absent, so unsetting it costs nothing.
unset ANTHROPIC_API_KEY
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
MCP_CONFIG_DIR="$LOG_DIR/.mcp-configs"
mkdir -p "$MCP_CONFIG_DIR"

# Expected shell: Git Bash (MSYS2/MinGW64) on Windows.
# Do NOT run from CMD or PowerShell — cygpath and nohup won't be available.
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "mac" ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *) echo "linux" ;;
  esac
}
OS=$(detect_os)

# ── WINDOW TITLE HELPER ───────────────────────────────────────
set_title() {
  printf '\033]0;%s\007' "$1"
}

# ── AGENT TRACKING ────────────────────────────────────────────
AGENT_PIDS=()
AGENT_NAMES=()
SHIFT_NAME="Unknown"
KEEP_AWAKE_PID=""
ACTIVE_SHIFT_FILE="$LOG_DIR/active-shift.txt"
AGENT_TIMEOUT="${AGENT_TIMEOUT:-30m}"
CLEANUP_DONE=false
SHIFT_COMPLETED=false

# ── CLEANUP TRAP ─────────────────────────────────────────────
# Handles: Ctrl+C, normal exit, TERM signal.
# Kills keep-awake, all tracked agents, removes shift tracking file.
cleanup() {
  if [ "$CLEANUP_DONE" = "true" ]; then return; fi
  CLEANUP_DONE=true

  echo ""
  echo "┌──────────────────────────────────────────┐"
  echo "│  CLEANUP — shutting down shift processes  │"
  echo "└──────────────────────────────────────────┘"

  # Kill keep-awake
  if [ -n "$KEEP_AWAKE_PID" ] && kill -0 "$KEEP_AWAKE_PID" 2>/dev/null; then
    kill "$KEEP_AWAKE_PID" 2>/dev/null
    echo "  ✓ Keep-awake stopped (PID $KEEP_AWAKE_PID)"
  fi

  # Kill running agents: TERM first, wait 5s, then KILL
  local KILLED=0
  for pid in "${AGENT_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      KILLED=$((KILLED + 1))
    fi
  done
  if [ "$KILLED" -gt 0 ]; then
    echo "  Sent TERM to $KILLED agent(s), waiting 5s..."
    sleep 5
    for pid in "${AGENT_PIDS[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null
        echo "  Force-killed PID $pid"
      fi
    done
  fi

  # Clean up launcher scripts for this shift's agents
  for name in "${AGENT_NAMES[@]}"; do
    rm -f "$LOG_DIR/launch-${name}.sh"
  done

  # Remove active-shift tracking file
  rm -f "$ACTIVE_SHIFT_FILE"

  # Only write ENDED if shift never completed normally (interrupted/crashed)
  if [ "$SHIFT_COMPLETED" = "false" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") | $SHIFT_NAME | ENDED (interrupted)" >> "$LOG_DIR/shift-history.log"
  fi
  echo "  ✓ Cleanup complete"
}
trap cleanup EXIT INT TERM

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  DukOS — Multi-Agent Studio              ║"
echo "║  $TIMESTAMP  |  $OS"
# Check holiday mode status
HM_CONFIG="$SCRIPT_DIR/config/holiday-mode.json"
if [ -f "$HM_CONFIG" ]; then
  HM_ACTIVE=$(python3 -c "import json; d=json.load(open('$HM_CONFIG')); print(d.get('active','false'))" 2>/dev/null || echo "false")
  HM_END=$(python3 -c "import json; d=json.load(open('$HM_CONFIG')); print(d.get('end_date',''))" 2>/dev/null || echo "")
  if [ "$HM_ACTIVE" = "True" ]; then
    echo "║  ⛱  HOLIDAY MODE ACTIVE (until $HM_END)"
  fi
fi
echo "╚══════════════════════════════════════════╝"

# ── PAUSE CHECK ───────────────────────────────────────────────
# Belt-and-suspenders: scheduled tasks are disabled on pause, but this catches
# manual `bash run.sh` runs and any admin-locked tasks that can't be disabled.
if [ -f "$SCRIPT_DIR/tools/pause.sh" ]; then
  if bash "$SCRIPT_DIR/tools/pause.sh" check 2>/dev/null; then
    echo ""
    echo "  DukOS IS PAUSED — no agents will launch."
    bash "$SCRIPT_DIR/tools/pause.sh" status 2>/dev/null | sed 's/^/    /'
    echo "  Resume early: bash tools/pause.sh resume"
    echo "$(date +'%Y-%m-%d %H:%M:%S') | SKIPPED (paused)" >> "$LOG_DIR/shift-history.log"
    SHIFT_COMPLETED=true
    exit 0
  elif [ -f "$SCRIPT_DIR/config/pause.json" ] && grep -q '"active": true' "$SCRIPT_DIR/config/pause.json" 2>/dev/null; then
    # Self-heal: pause expired but wake task missed (PC was asleep)
    echo "  Pause expired but flag was stale — running auto-resume..."
    bash "$SCRIPT_DIR/tools/pause.sh" resume >> "$LOG_DIR/pause-wake.log" 2>&1
    echo "  Auto-resume done. Continuing shift."
  fi
fi

# ── STEP 1: GITHUB BACKUP ─────────────────────────────────────
github_backup() {
  echo ""
  echo "▶ [1/3] GitHub Backup"
  cd "$SCRIPT_DIR" || return 1

  if [ ! -d ".git" ]; then
    git init
    read -p "  GitHub repo URL (or Enter to skip): " REMOTE_URL
    [ -n "$REMOTE_URL" ] && git remote add origin "$REMOTE_URL"
  fi

  REMOTE=$(git remote get-url origin 2>/dev/null)
  git add -A

  if git diff --cached --quiet; then
    echo "  Nothing to commit — already clean"
  else
    git commit -m "backup: pre-run $TIMESTAMP"
    echo "  Committed changes"
  fi

  if [ -n "$REMOTE" ]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    if git push origin "$BRANCH" 2>/dev/null; then
      echo "  ✓ Pushed to GitHub ($BRANCH)"
    else
      echo "  ✗ Push failed — running with local backup only"
    fi
  else
    echo "  No remote configured — local only"
  fi
}

# ── STEP 2: KEEP AWAKE ────────────────────────────────────────
setup_keep_awake() {
  echo ""
  echo "▶ [2/3] Keep Awake"
  case $OS in
    windows)
      AWAKE_SCRIPT="$LOG_DIR/keep-awake.ps1"
      printf 'Add-Type -AssemblyName System.Windows.Forms\nwhile ($true) { [System.Windows.Forms.SendKeys]::SendWait("{SCROLLLOCK}"); Start-Sleep -Seconds 180 }' > "$AWAKE_SCRIPT"
      powershell.exe -WindowStyle Minimized -ExecutionPolicy Bypass -File "$(cygpath -w "$AWAKE_SCRIPT")" </dev/null &
      KEEP_AWAKE_PID=$!
      echo "  ✓ Windows keep-awake running (PID $KEEP_AWAKE_PID, minimized)"
      ;;
    mac)
      caffeinate -dis </dev/null &
      KEEP_AWAKE_PID=$!
      echo "  ✓ caffeinate active (PID $KEEP_AWAKE_PID)"
      ;;
    *)
      echo "  Skipped (Linux)"
      ;;
  esac
}

# ── STEP 2.5: CLEANUP STALE SHIFT ─────────────────────────────
# Reads active-shift.txt from a PREVIOUS shift (if it exists).
# Only kills PIDs explicitly written by run_agent() — never touches
# interactive sessions or anything not in the tracking file.
cleanup_stale_shift() {
  echo ""
  echo "▶ [2.5/3] Stale Shift Cleanup"

  # One-time migration: remove legacy PID files (never read)
  local LEGACY_COUNT
  LEGACY_COUNT=$(find "$LOG_DIR" -maxdepth 1 -name 'pids-*.txt' 2>/dev/null | wc -l)
  if [ "$LEGACY_COUNT" -gt 0 ]; then
    rm -f "$LOG_DIR"/pids-*.txt
    echo "  Cleaned $LEGACY_COUNT legacy pids-*.txt files"
  fi

  if [ ! -f "$ACTIVE_SHIFT_FILE" ]; then
    echo "  ✓ No stale shift found — clean start"
    return
  fi

  echo "  Found stale shift file — checking for zombie processes..."
  local KILLED=0
  local ALREADY_DEAD=0

  while IFS='|' read -r PID NAME TS MODEL LAUNCHER; do
    [ -z "$PID" ] && continue
    if kill -0 "$PID" 2>/dev/null; then
      echo "  Killing stale agent: $NAME (PID $PID, started $TS)"
      kill "$PID" 2>/dev/null
      KILLED=$((KILLED + 1))
    else
      ALREADY_DEAD=$((ALREADY_DEAD + 1))
    fi
    # Clean up launcher if it still exists
    [ -n "$LAUNCHER" ] && rm -f "$LAUNCHER"
  done < "$ACTIVE_SHIFT_FILE"

  # Grace period then force-kill survivors
  if [ "$KILLED" -gt 0 ]; then
    echo "  Waiting 3s for graceful shutdown..."
    sleep 3
    while IFS='|' read -r PID NAME TS MODEL LAUNCHER; do
      [ -z "$PID" ] && continue
      if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" 2>/dev/null
        echo "  Force-killed: $NAME (PID $PID)"
      fi
    done < "$ACTIVE_SHIFT_FILE"
  fi

  rm -f "$ACTIVE_SHIFT_FILE"
  echo "  ✓ Stale cleanup done (killed: $KILLED, already exited: $ALREADY_DEAD)"
}

# ── STEP 3: LAUNCH AGENTS ─────────────────────────────────────
# ── MODEL TIERS ───────────────────────────────────────────────
# Opus 4.8   → orchestrator, research, portfolio-analyst, growth  (complex reasoning)
# Sonnet 4.6 → gamedev, builder, content, marketing, outreach, qa, data, copywriter, ... (default)
# Haiku 4.5  → admin  (lightweight ops, cheapest)
get_model() {
  case $1 in
    orchestrator|research|portfolio-analyst|growth) echo "claude-opus-4-8" ;;
    admin) echo "claude-haiku-4-5" ;;
    *)     echo "claude-sonnet-4-6" ;;
  esac
}

# ── EFFORT TIERS ──────────────────────────────────────────────
# high   → orchestrator, research, portfolio-analyst, qa, review, security
#          (multi-source synthesis, planning, risk analysis, bug detection)
# medium → builder, gamedev, content, copywriter, marketing, outreach, data (default)
#          (sequential code/creative work, no deep reasoning needed)
# low    → admin
#          (simple ops: file management, task routing, status checks)
get_effort() {
  case $1 in
    orchestrator|research|portfolio-analyst|qa|review|security) echo "high" ;;
    admin) echo "low" ;;
    *) echo "medium" ;;
  esac
}

# ── PER-AGENT MCP CONFIG ─────────────────────────────────────
# Most agents need zero MCP servers. This generates a config file
# with only the MCPs that agent actually uses, then passes
# --strict-mcp-config to prevent loading the global set.
# Result: a handful of MCP processes per shift instead of dozens.
generate_mcp_config() {
  local NAME=$1
  local CONFIG_FILE="$MCP_CONFIG_DIR/${NAME}.json"

  if [ -f "$SCRIPT_DIR/tools/agent-mcp-config.py" ]; then
    python3 "$SCRIPT_DIR/tools/agent-mcp-config.py" "$NAME" "$CONFIG_FILE" 2>>"$LOG_DIR/mcp-config-warnings.log"
  fi

  # Fallback: if generation failed, create empty config (no MCPs)
  if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"mcpServers":{}}' > "$CONFIG_FILE"
  fi

  echo "$CONFIG_FILE"
}

# ── RESEARCH FREQUENCY GATE ───────────────────────────────────
# Research is token-heavy — cap at 12 runs per 7-day rolling window so it
# stays the primary pre-launch activity without exhausting the token budget.
check_research_frequency() {
  local COUNT=0
  # Compute cutoff date: 7 days ago. Try GNU date first, fall back to PowerShell on Windows.
  local CUTOFF
  CUTOFF=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null) || \
  CUTOFF=$(powershell.exe -Command "(Get-Date).AddDays(-7).ToString('yyyy-MM-dd')" 2>/dev/null | tr -d '\r')

  if [ -z "$CUTOFF" ]; then
    echo "  ⚠ Could not determine cutoff date — research frequency check skipped" >&2
    echo 0
    return
  fi

  for f in "$LOG_DIR"/research-*.log; do
    [ -f "$f" ] || continue
    # Filename format: research-YYYY-MM-DD_HH-MM.log
    FILE_DATE=$(basename "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    [ -z "$FILE_DATE" ] && continue
    # String comparison works for ISO dates (lexicographic = chronological)
    [[ "$FILE_DATE" > "$CUTOFF" ]] && COUNT=$((COUNT + 1))
  done
  echo "$COUNT"
}

run_research_gated() {
  local COUNT
  COUNT=$(check_research_frequency)
  if [ "$COUNT" -ge 12 ]; then
    echo "  ⟳ Research skipped — already ran $COUNT times in the last 7 days (max: 12)"
  else
    echo "  ✓ Research frequency: $COUNT/12 this week — launching"
    run_agent "research"
  fi
}

# ── COMPETITION-RESEARCH SUNDAY GATE ─────────────────────────
# Runs once per week on Sunday Night 1 only — keeps data fresh without burning tokens nightly.
run_competition_sunday() {
  local DOW
  DOW=$(date +%u)  # 1=Mon ... 7=Sun
  if [ "$DOW" = "7" ]; then
    echo "  ✓ Sunday — launching competition-research agent"
    run_agent "competition-research"
  else
    echo "  ⟳ Competition-research skipped — runs Sundays only (today: $(date +%A))"
  fi
}

run_agent() {
  local NAME=$1
  local PROMPT_FILE="$SCRIPT_DIR/agents/prompts/$NAME.md"
  local LOG_FILE="$LOG_DIR/${NAME}-${TIMESTAMP}.log"

  local MODEL EFFORT MCP_CONFIG_FILE
  MODEL=$(get_model "$NAME")
  EFFORT=$(get_effort "$NAME")
  MCP_CONFIG_FILE=$(generate_mcp_config "$NAME")

  if [ ! -f "$PROMPT_FILE" ]; then
    echo "  ✗ Missing prompt: $PROMPT_FILE"
    return 1
  fi

  # Use --print mode (non-interactive) with a short trigger prompt
  TRIGGER="You are the $NAME agent. Read your full instructions from agents/prompts/$NAME.md and execute them. Work autonomously until tasks are complete or context limit reached."

  # Count startup tokens before launch (writes first line to log, appends to token-usage.json).
  # count-tokens.sh uses a local char-based estimate when no ANTHROPIC_API_KEY is set (the
  # fleet runs on subscription, so the key is intentionally unset above), so this runs on
  # every launch.
  if [ -f "$SCRIPT_DIR/tools/count-tokens.sh" ]; then
    bash "$SCRIPT_DIR/tools/count-tokens.sh" "$NAME" >> "$LOG_FILE" 2>&1
  fi

  if [ "$OS" = "windows" ]; then
    # Write a launcher script to avoid quoting/space issues with long trigger strings
    LAUNCHER="$LOG_DIR/launch-${NAME}.sh"
    # Use printf %q to safely quote paths that may contain spaces or special characters
    QUOTED_DIR=$(printf '%q' "$SCRIPT_DIR")
    QUOTED_LOG=$(printf '%q' "$LOG_FILE")
    QUOTED_MCP=$(printf '%q' "$(cygpath -w "$MCP_CONFIG_FILE" 2>/dev/null || echo "$MCP_CONFIG_FILE")")
    cat > "$LAUNCHER" <<LAUNCHER_EOF
#!/bin/bash
export CI=true
export NO_UPDATE_NOTIFIER=1
export AGENT_NAME=$NAME
cd $QUOTED_DIR
timeout --kill-after=5m $AGENT_TIMEOUT \
  claude --dangerously-skip-permissions --model $MODEL --effort $EFFORT --strict-mcp-config --mcp-config $QUOTED_MCP --print "$TRIGGER" >> $QUOTED_LOG 2>&1
CLAUDE_EXIT=\$?
unset AGENT_NAME
if [ \$CLAUDE_EXIT -eq 124 ]; then
  echo "=== Agent $NAME finished: TIMEOUT after $AGENT_TIMEOUT ===" >> $QUOTED_LOG
elif [ \$CLAUDE_EXIT -eq 0 ]; then
  echo "=== Agent $NAME finished: OK ===" >> $QUOTED_LOG
else
  echo "=== Agent $NAME finished: EXIT \$CLAUDE_EXIT (check for token exhaustion) ===" >> $QUOTED_LOG
fi
LOG_SIZE=\$(wc -c < $QUOTED_LOG 2>/dev/null || echo 0)
ESTIMATED=\$(python3 -c "import math; print(round(\$LOG_SIZE / 4))" 2>/dev/null || echo 0)
echo "=== [$NAME] session estimated tokens: \$ESTIMATED ===" >> $QUOTED_LOG
exit \$CLAUDE_EXIT
LAUNCHER_EOF
    # Use nohup + background so output redirects work (start opens detached window, loses stdout)
    nohup bash "$LAUNCHER" >> "$LOG_FILE" 2>&1 &
  else
    LAUNCHER="$LOG_DIR/launch-${NAME}.sh"
    cat > "$LAUNCHER" <<LAUNCHER_EOF
#!/bin/bash
export CI=true
export NO_UPDATE_NOTIFIER=1
export AGENT_NAME=$NAME
cd "$SCRIPT_DIR"
timeout --kill-after=5m $AGENT_TIMEOUT \
  claude --dangerously-skip-permissions --model $MODEL --effort $EFFORT --strict-mcp-config --mcp-config "$MCP_CONFIG_FILE" --print "$TRIGGER" >> "$LOG_FILE" 2>&1
CLAUDE_EXIT=\$?
unset AGENT_NAME
if [ \$CLAUDE_EXIT -eq 124 ]; then
  echo "=== Agent $NAME finished: TIMEOUT after $AGENT_TIMEOUT ===" >> "$LOG_FILE"
elif [ \$CLAUDE_EXIT -eq 0 ]; then
  echo "=== Agent $NAME finished: OK ===" >> "$LOG_FILE"
else
  echo "=== Agent $NAME finished: EXIT \$CLAUDE_EXIT (check for token exhaustion) ===" >> "$LOG_FILE"
fi
LOG_SIZE=\$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
ESTIMATED=\$(python3 -c "import math; print(round(\$LOG_SIZE / 4))" 2>/dev/null || echo 0)
echo "=== [$NAME] session estimated tokens: \$ESTIMATED ===" >> "$LOG_FILE"
exit \$CLAUDE_EXIT
LAUNCHER_EOF
    nohup bash "$LAUNCHER" >> "$LOG_FILE" 2>&1 &
  fi

  # Track PID for monitoring and active-shift file
  AGENT_PIDS+=($!)
  AGENT_NAMES+=("$NAME")
  echo "$!|$NAME|$(date +"%Y-%m-%d %H:%M:%S")|$MODEL|$LAUNCHER" >> "$ACTIVE_SHIFT_FILE"
  echo "  ✓ Started: $NAME [$MODEL / effort:$EFFORT / timeout:$AGENT_TIMEOUT] (log: logs/${NAME}-${TIMESTAMP}.log)"
  sleep 3
}

NEEDS_REVIEW=false

# ── READ SHIFT SELECTION EARLY ────────────────────────────────
# IMPORTANT: Read stdin BEFORE any PowerShell processes are spawned.
# powershell.exe inherits bash's stdin fd; if launched first it consumes
# the piped shift number, leaving read SHIFT with empty input.
# Scheduled callers use: echo 'N' | bash run.sh
PRESELECTED_SHIFT=""
if [ -p /dev/stdin ] 2>/dev/null; then
  read PRESELECTED_SHIFT 2>/dev/null || true
else
  read -t 0.5 PRESELECTED_SHIFT 2>/dev/null || PRESELECTED_SHIFT=""
fi

check_claude_cli() {
  if ! command -v claude &>/dev/null; then
    echo ""
    echo "  ✗ ERROR: 'claude' CLI not found in PATH."
    echo "    Install Claude Code and ensure it is in PATH before running run.sh."
    echo "    See: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
  fi
}

launch_agents() {
  echo ""
  echo "▶ [3/3] Launch Agents"
  echo ""
  echo "  SHIFT MENU:"
  echo "  ┌────┬──────────────────────────┬─────────────────────────────────────────────────┐"
  echo "  │  1 │ Night Shift 1   (9:00pm) │ gamedev+builder+content+research+marketing+      │"
  echo "  │    │                          │ admin+orchestrator+copywriter+tiktok (+comp Sun) │"
  echo "  │  2 │ Handoff         (2:00am) │ orchestrator only (<30 min)                      │"
  echo "  │  3 │ Night Shift 2   (2:30am) │ marketing+admin+outreach+community               │"
  echo "  │  4 │ Morning Review  (7:00am) │ orchestrator+admin+qa+security                   │"
  echo "  │  5 │ Daytime Admin   (12:00pm)│ admin+data                                       │"
  echo "  │  6 │ Evening Prep    (7:05pm) │ orchestrator (prep night shift)                  │"
  echo "  │  7 │ Custom                   │ pick your agents                                 │"
  echo "  │  8 │ 10am Burst      (10:00am)│ builder+research+admin+portfolio-analyst+seo+aso │"
  echo "  │  9 │ Strategy Pass   (1:00pm) │ orchestrator+research+growth                     │"
  echo "  │ 10 │ Afternoon Push  (4:00pm) │ content+marketing                                │"
  echo "  │ 11 │ Evening Review  (7:00pm) │ review only (Layer 2 backfill, gap-closer)       │"
  echo "  └────┴──────────────────────────┴─────────────────────────────────────────────────┘"
  echo ""
  if [ -n "$PRESELECTED_SHIFT" ]; then
    SHIFT="$PRESELECTED_SHIFT"
    echo "  Auto-selected shift: $SHIFT"
  else
    read -p "  Select shift (1-11): " SHIFT
  fi

  # Save current HEAD so review agent knows which commits are from this session.
  # Skip for shift 11 (Evening Review) — that shift WANTS the baseline from the
  # last code shift so it can scan forward across the gap.
  if [ "$SHIFT" != "11" ]; then
    git rev-parse HEAD 2>/dev/null > "$LOG_DIR/review-baseline.txt" || echo "none" > "$LOG_DIR/review-baseline.txt"
  fi

  case $SHIFT in
    1)
      SHIFT_NAME="Night Shift 1"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Night Shift 1 (full off-peak roster)..."
      run_agent "gamedev"
      run_agent "builder"
      run_agent "content"
      run_research_gated
      run_competition_sunday
      run_agent "marketing"
      run_agent "admin"
      run_agent "orchestrator"
      run_agent "copywriter"
      run_agent "tiktok"
      NEEDS_REVIEW=true
      ;;
    2)
      SHIFT_NAME="Handoff"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Handoff (Orchestrator only)..."
      run_agent "orchestrator"
      ;;
    3)
      SHIFT_NAME="Night Shift 2"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Night Shift 2 (marketing+admin+outreach+community)..."
      run_agent "marketing"
      run_agent "admin"
      run_agent "outreach"
      run_agent "community"
      ;;
    4)
      SHIFT_NAME="Morning Review"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Morning Review (orchestrator+admin+qa+security)..."
      run_agent "orchestrator"
      run_agent "admin"
      run_agent "qa"
      run_agent "security"
      ;;
    5)
      SHIFT_NAME="Daytime Admin"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Daytime Admin (admin+data)..."
      run_agent "admin"
      run_agent "data"
      ;;
    6)
      SHIFT_NAME="Evening Prep"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Evening Prep..."
      run_agent "orchestrator"
      ;;
    7)
      SHIFT_NAME="Custom"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Available agents: orchestrator research growth competition-research marketing"
      echo "                    content copywriter seo aso tiktok community outreach builder"
      echo "                    gamedev qa data portfolio-analyst admin review assistant"
      echo "                    habit habit-morning habit-review security"
      read -p "  Enter names (space-separated): " CUSTOM
      for agent in $CUSTOM; do
        run_agent "$agent"
      done
      ;;
    8)
      SHIFT_NAME="10am Burst"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting 10am Burst (builder+research+admin+portfolio-analyst+seo+aso)..."
      run_agent "builder"
      run_research_gated
      run_agent "admin"
      run_agent "portfolio-analyst"
      run_agent "seo"
      run_agent "aso"
      NEEDS_REVIEW=true
      ;;
    9)
      SHIFT_NAME="Strategy Pass"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Strategy Pass (orchestrator+research+growth — market intel → direction)..."
      run_agent "orchestrator"
      run_research_gated
      run_agent "growth"
      ;;
    10)
      SHIFT_NAME="Afternoon Push"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Afternoon Push (content+marketing — distribute what research found)..."
      run_agent "content"
      run_agent "marketing"
      ;;
    11)
      SHIFT_NAME="Evening Review"
      set_title "DukOS — $SHIFT_NAME — LAUNCHING"
      echo "  Starting Evening Review (review only — Layer 2 backfill across the day)..."
      run_agent "review"
      ;;
    *)
      echo "  Invalid selection"
      exit 1
      ;;
  esac
}

# ── WAIT & MONITOR ────────────────────────────────────────────
# Wait for all agents, update title, auto-close on success
wait_for_agents() {
  local TOTAL=${#AGENT_PIDS[@]}
  if [ "$TOTAL" -eq 0 ]; then return; fi

  echo ""
  echo "  Monitoring $TOTAL agent(s) — window will close automatically when all finish."
  echo "  (Press Ctrl+C to stop all agents and exit.)"
  echo ""

  # Update title: LAUNCHING → RUNNING
  set_title "DukOS — $SHIFT_NAME — RUNNING (0/$TOTAL)"

  local DONE=0
  local ERRORS=0
  local TIMEOUTS=0
  for i in "${!AGENT_PIDS[@]}"; do
    wait "${AGENT_PIDS[$i]}"
    local EXIT_CODE=$?
    # If cleanup fired (Ctrl+C), stop processing — ENDED already logged by trap
    if [ "$CLEANUP_DONE" = "true" ]; then return; fi
    local AGENT="${AGENT_NAMES[$i]}"
    DONE=$((DONE + 1))
    # Clean up launcher script after agent finishes
    rm -f "$LOG_DIR/launch-${AGENT}.sh"
    if [ "$EXIT_CODE" -eq 0 ]; then
      echo "  ✓ $AGENT — done ($DONE/$TOTAL)"
    elif [ "$EXIT_CODE" -eq 124 ]; then
      echo "  ⏱ $AGENT — TIMEOUT after $AGENT_TIMEOUT ($DONE/$TOTAL)"
      TIMEOUTS=$((TIMEOUTS + 1))
      ERRORS=$((ERRORS + 1))
    elif [ "$EXIT_CODE" -eq 130 ] || [ "$EXIT_CODE" -eq 143 ]; then
      echo "  ↩ $AGENT — stopped by signal ($DONE/$TOTAL)"
    else
      echo "  ✗ $AGENT — exit $EXIT_CODE (token exhaustion?) ($DONE/$TOTAL)"
      ERRORS=$((ERRORS + 1))
    fi
    set_title "DukOS — $SHIFT_NAME — RUNNING ($DONE/$TOTAL)"
  done

  # Write shift-completed marker
  echo "$(date +"%Y-%m-%d %H:%M:%S") | $SHIFT_NAME | COMPLETED (errors: $ERRORS, timeouts: $TIMEOUTS)" >> "$LOG_DIR/shift-history.log"
  SHIFT_COMPLETED=true

  echo ""
  if [ "$ERRORS" -eq 0 ]; then
    set_title "DukOS — $SHIFT_NAME — DONE"
    echo "  All $TOTAL agent(s) finished successfully."
    echo ""
    if [ "$NEEDS_REVIEW" = "false" ]; then
      echo "  Closing window in 10s... (Ctrl+C to keep open)"
      sleep 10
    fi
  else
    set_title "DukOS — $SHIFT_NAME — $ERRORS ERROR(S)"
    local MSG="$ERRORS agent(s) exited with errors"
    [ "$TIMEOUTS" -gt 0 ] && MSG="$MSG ($TIMEOUTS timed out)"
    echo "  $MSG — review logs/ for details."
    echo "  Window kept open for inspection."
  fi
}

# ── MAIN ──────────────────────────────────────────────────────
check_claude_cli
github_backup
setup_keep_awake
cleanup_stale_shift
launch_agents

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  AGENTS RUNNING                          ║"
echo "║  Logs:     logs/                         ║"
echo "║  Briefing: reports/daily-briefing.md     ║"
echo "║  Tasks:    tasks/board.md                ║"
echo "╚══════════════════════════════════════════╝"
echo ""

wait_for_agents

# ── POST-SHIFT REVIEW GATE ─────────────────────────────────────
# Runs sequentially after builder/gamedev finish their commits.
# Only on shifts that include code-writing agents (shifts 1 and 8).
if [ "$NEEDS_REVIEW" = "true" ]; then
  echo ""
  echo "▶ [4/4] Post-Build Review"
  echo "  Running review agent against this session's commits..."
  AGENT_PIDS=()
  AGENT_NAMES=()
  SHIFT_NAME="Post-Build Review"
  SHIFT_COMPLETED=false
  run_agent "review"
  wait_for_agents
  echo "  Review complete. See reports/review/ for findings."
fi
