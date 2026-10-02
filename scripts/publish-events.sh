#!/usr/bin/env bash
# publish-events.sh — copies gate events from the shared, untracked log (<git common dir>/vera-events.jsonl, or
# $VERA_EVENTS_FILE) into the tracked .harness/events.jsonl that the weekly harness-improve routine reads.
# Appends the valid JSON lines the tracked file does not hold yet (exact match), in their original order, so a re-run
# adds nothing. /finish-task runs it before staging the state files. Exit codes: 0 ok · 2 environment (not a checkout).
set -uo pipefail
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)" || { echo "publish-events: not inside a git checkout" >&2; exit 2; }
SHARED="${VERA_EVENTS_FILE:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/vera-events.jsonl}"
TRACKED="$ROOT/.harness/events.jsonl"
added=0
if [ -s "$SHARED" ]; then
  mkdir -p "$ROOT/.harness" && touch "$TRACKED"
  # A truncated line stays out of the tracked file. FILENAME, not NR==FNR: with an empty tracked file NR==FNR would
  # also hold for the shared lines and skip them all.
  new="$(jq -rR 'select(try (fromjson | type == "object") catch false)' "$SHARED" \
    | awk -v tracked="$TRACKED" 'FILENAME == tracked {seen[$0]; next} !($0 in seen)' "$TRACKED" -)"
  if [ -n "$new" ]; then
    if [ -s "$TRACKED" ] && [ -n "$(tail -c1 "$TRACKED")" ]; then echo >> "$TRACKED"; fi   # never glue two events
    printf '%s\n' "$new" >> "$TRACKED"
    added="$(printf '%s\n' "$new" | wc -l | tr -d ' ')"
  fi
fi
echo "RESULT publish-events exit=0 added=$added"
