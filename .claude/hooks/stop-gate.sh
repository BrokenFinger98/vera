#!/usr/bin/env bash
# Stop hook — refuse to end the turn while source changes fail the fast gate (spec §6 row 1, trial D7).
# exit 2 + stderr = Claude must keep working. Loop guard: stop_hook_active. Concurrency guard: another Gradle client.
set -uo pipefail
INPUT="$(cat)"
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOG="$ROOT/.claude/hooks/log-gate-event.sh"

# Already blocked once this turn → let it stop (prevents infinite loops).
if printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then exit 0; fi

# Only care about source changes (tracked or untracked) in code directories.
changed="$(git -C "$ROOT" status --porcelain -- platform apps ingestion bootstrap build.gradle.kts settings.gradle.kts gradle 2>/dev/null \
  | grep -E '\.(kt|kts|java|sql|yaml|yml|toml)$' | head -50)"
[ -z "$changed" ] && exit 0

# A worker subagent's Gradle run would share build/ and produce false failures (wiki 2026-09-09 lesson).
if pgrep -f 'GradleWrapperMain|gradlew' >/dev/null 2>&1; then
  "$LOG" stop-gate skipped-concurrent-gradle "another Gradle client is running"
  echo "stop-gate: another Gradle build is running; skipped. Re-run ./scripts/check.sh when it finishes." >&2
  exit 0
fi

out="$("$ROOT/scripts/check.sh" 2>&1)"
code=$?
if [ $code -eq 0 ]; then exit 0; fi

"$LOG" stop-gate check.sh-failed "$(printf '%s' "$out" | grep -E 'RESULT|tests,|FAILED|error:' | tail -5)"
{
  echo "🛑 stop-gate: ./scripts/check.sh failed (exit $code). Fix before stopping. Last 40 lines (Gradle boilerplate is ~12, so the failing test name survives):"
  printf '%s\n' "$out" | tail -40
  echo "Order: spotlessApply → build/reports/detekt/<source set>.md → test-results XML → archTest rule name. Never weaken a test or rule to pass."
} >&2
exit 2
