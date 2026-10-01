#!/usr/bin/env bash
# PreToolUse(Bash) — Vera-specific destructive commands, on top of the global block-danger.sh. exit 2 = blocked.
set -uo pipefail
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
[ -n "$CMD" ] || exit 0
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOG="$ROOT/.claude/hooks/log-gate-event.sh"

block() {
  "$LOG" block-danger "$2" "$CMD"
  echo "🚫 blocked: $1" >&2
  echo "   command: $CMD" >&2
  echo "   $3" >&2
  exit 2
}
m() { printf '%s' "$CMD" | grep -qiE "$1"; }

m 'flyway(Clean|Repair)|flyway[[:space:]]+(clean|repair)' && block "Flyway clean/repair" flyway-clean "Migrations are immutable; fix forward with a new V<timestamp>__*.sql."
m 'compose[[:space:]]+down.*(-v|--volumes)' && block "compose down with volumes" compose-down-volumes "Volumes hold the demo database; use 'docker compose down' without -v."
m 'drop[[:space:]]+schema' && block "DROP SCHEMA" drop-schema "Schema changes go through Flyway migrations reviewed in a PR."
m 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)' && block "discarding all working-tree changes" git-discard-all "Discard single files by path, never the whole tree."
m 'git[[:space:]]+push.*(--force|-f([[:space:]]|$))' && block "force push" force-push "History is linear and protected; open a new commit instead."
exit 0
