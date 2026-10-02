#!/usr/bin/env bash
# SessionStart hook — re-injects out-of-session memory (also after compaction) and installs the push gate.
# Fail-open: never block a session start.
cat >/dev/null 2>&1
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0

# 1. Idempotently point git at the versioned hooks
if [ -d "$ROOT/.githooks" ] && [ "$(git -C "$ROOT" config core.hooksPath 2>/dev/null)" != ".githooks" ]; then
  git -C "$ROOT" config core.hooksPath .githooks 2>/dev/null || true
fi

ctx=""
add() { ctx="${ctx}=== $1 ===
$2

"; }

# 2. goal (personal, may be absent on a fresh clone)
[ -f "$ROOT/.harness/state/goal.md" ] && add ".harness/state/goal.md" "$(cat "$ROOT/.harness/state/goal.md")"

# 3. progress — only the part above the archive marker (constant-cost injection, spec §10). The marker is a line of
#    its own, so prose that quotes it does not cut the injection short.
if [ -f "$ROOT/.harness/state/progress.md" ]; then
  add ".harness/state/progress.md (above <!-- ARCHIVE -->)" "$(awk '/^<!-- ARCHIVE -->[[:space:]]*$/{exit} {print}' "$ROOT/.harness/state/progress.md")"
fi

# 4. wiki index — Decisions section only
if [ -f "$ROOT/docs/llm-wiki/index.md" ]; then
  add "docs/llm-wiki/index.md (Decisions)" "$(awk '/^## Decisions/{f=1} /^## /&&!/^## Decisions/{f=0} f' "$ROOT/docs/llm-wiki/index.md")"
fi

# 5. gate events in the last 7 days — a nudge, not a report. The shared log (log-gate-event.sh) holds the firings of
#    every worktree; a fresh clone has only the tracked copy. fromjson? skips a truncated line instead of losing the rest.
events="${VERA_EVENTS_FILE:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/vera-events.jsonl}"
[ -s "$events" ] || events="$ROOT/.harness/events.jsonl"
if [ -f "$events" ]; then
  since="$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)"
  summary="$(jq -rR --arg since "$since" 'fromjson? | objects | select(.ts >= $since) | "\(.gate)/\(.rule)"' "$events" 2>/dev/null | sort | uniq -c | sort -rn | head -5)"
  [ -n "$summary" ] && add "gate events, last 7 days (count gate/rule)" "$summary"
fi

[ -z "$ctx" ] && exit 0
jq -n --arg c "[out-of-session memory — session start or compaction recovery. Check the request against the Decisions list; if it conflicts with an ADR, open that ADR before acting.]
$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}' 2>/dev/null
exit 0
