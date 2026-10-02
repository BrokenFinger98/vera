#!/usr/bin/env bash
# log-gate-event.sh <gate> <rule> <detail...>
# Appends one JSON line to the shared gate-event log <git common dir>/vera-events.jsonl: untracked and one file for the
# main checkout and every worktree, so a firing never dirties a tree. $VERA_EVENTS_FILE overrides the path (tests).
# The only writer of that log (spec §10.1 Capture); scripts/publish-events.sh copies it into .harness/events.jsonl.
# gate  : block-danger | stop-gate | pre-push-guard | wiki-gate | critic | ci
# rule  : short machine name, e.g. "deleted-test-file", "check.sh-failed", "force-push"
# detail: free text; secret-looking assignments are masked (below), then cut to 300 bytes; jq -a escapes non-ASCII
set -uo pipefail
export LC_ALL=C   # bytes, not characters: invalid UTF-8 in a detail must not stop tr, sed or cut
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ $# -ge 2 ] || exit 0
gate="$1"; rule="$2"; shift 2
# A NAME=value or --long-option=value whose name holds one of these words, in any case (PGPASSWORD, GH_TOKEN,
# aws_secret_access_key, --api-key), keeps only NAME=***; every other assignment (exit=1, --source=HEAD) stays readable.
SENSITIVE='(pass|pwd|secret|token|key|auth|cred|session|cookie)'
detail="$(printf '%s' "$*" | tr '\n' ' ' \
  | sed -E -e "s/(--[A-Za-z0-9-]*${SENSITIVE}[A-Za-z0-9-]*)=[^[:space:]]+/\1=***/gI" \
           -e "s/([A-Za-z0-9_]*${SENSITIVE}[A-Za-z0-9_]*)=[^[:space:]]+/\1=***/gI" \
  | cut -c1-300)"
branch="$(git -C "$ROOT" branch --show-current 2>/dev/null)"; [ -n "$branch" ] || branch=detached
ticket="$(printf '%s' "$branch" | sed -nE 's#^[a-z]+/([0-9]+)-.*#\1#p')"
EVENTS="${VERA_EVENTS_FILE:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/vera-events.jsonl}"
jq -acn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg gate "$gate" --arg rule "$rule" \
      --arg ticket "${ticket:-}" --arg branch "$branch" --arg detail "$detail" \
      '{ts:$ts, gate:$gate, rule:$rule, ticket:$ticket, branch:$branch, detail:$detail}' \
      >> "$EVENTS" 2>/dev/null || true
exit 0
