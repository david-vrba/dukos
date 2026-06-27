#!/usr/bin/env bash
# safe-rm.sh — reversible delete: moves paths into .trash/<timestamp>/ inside the repo
# instead of permanently deleting them, preserving structure and printing restore commands.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: bash tools/safe-rm.sh <path> [more paths...]" >&2
  echo "Moves each path into .trash/<timestamp>/ (reversible). Never hard-deletes." >&2
  exit 1
fi

# Repo root = parent of this script's tools/ directory.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
trash_dir="$repo_root/.trash/$timestamp"

moved=0
for target in "$@"; do
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    echo "skip (not found): $target" >&2
    continue
  fi

  # Absolute path of the target's parent + its basename (handles files and dirs).
  base="$(basename "$target")"
  parent_abs="$(cd "$(dirname "$target")" && pwd)"
  abs="$parent_abs/$base"

  # Relative to repo root when inside it; otherwise mirror the absolute path
  # (drive/leading slash stripped) so structure is preserved without collisions.
  case "$abs" in
    "$repo_root"/*) rel="${abs#"$repo_root"/}" ;;
    *)              rel="_external/$(echo "$abs" | sed -E 's#^[A-Za-z]:/?##; s#^/+##')" ;;
  esac

  dest="$trash_dir/$rel"
  mkdir -p "$(dirname "$dest")"
  mv "$abs" "$dest"
  moved=$((moved + 1))

  echo "moved:   $abs"
  echo "  -> $dest"
  echo "  restore: mkdir -p \"$(dirname "$abs")\" && mv \"$dest\" \"$abs\""
done

echo ""
echo "$moved item(s) moved to: $trash_dir"
echo "Nothing was permanently deleted. Empty .trash/ yourself to reclaim space."
