#!/usr/bin/env bash
# log-gate-event.sh <gate> <rule> <detail...>
# Appends one JSON line to .harness/events.jsonl. The only writer of that file (spec §10.1 Capture).
# gate  : block-danger | stop-gate | pre-push-guard | wiki-gate | critic | ci
# rule  : short machine name, e.g. "deleted-test-file", "check.sh-failed", "force-push"
# detail: free text (truncated to 300 chars)
set -uo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ $# -ge 2 ] || exit 0
gate="$1"; rule="$2"; shift 2
detail="$(printf '%s' "$*" | tr '\n' ' ' | cut -c1-300)"
branch="$(git -C "$ROOT" branch --show-current 2>/dev/null || echo unknown)"
ticket="$(printf '%s' "$branch" | sed -nE 's#^[a-z]+/([0-9]+)-.*#\1#p')"
mkdir -p "$ROOT/.harness"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg gate "$gate" --arg rule "$rule" \
      --arg ticket "${ticket:-}" --arg branch "$branch" --arg detail "$detail" \
      '{ts:$ts, gate:$gate, rule:$rule, ticket:$ticket, branch:$branch, detail:$detail}' \
      >> "$ROOT/.harness/events.jsonl" 2>/dev/null || true
exit 0
