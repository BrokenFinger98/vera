#!/usr/bin/env bash
# Stop hook — refuse to end the turn while source changes fail the fast gate (spec §6 row 1, trial D7).
# exit 2 + stderr = Claude must keep working. Loop guard: stop_hook_active. Concurrency guard: a Gradle build of this checkout.
set -uo pipefail
INPUT="$(cat)"
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOG="$ROOT/.claude/hooks/log-gate-event.sh"

# Already blocked once this turn → let it stop (prevents infinite loops).
if printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null 2>&1; then exit 0; fi

# Only care about source and build changes (tracked or untracked). -z names arrive unquoted, spaces included;
# --untracked-files=all lists the files of a new package directory instead of one 'dir/' entry.
changed="$(git -C "$ROOT" status --porcelain -z --untracked-files=all -- platform apps ingestion bootstrap \
  build.gradle.kts settings.gradle.kts gradle config gradle.properties 2>/dev/null \
  | tr '\0' '\n' | grep -E '\.(kt|kts|java|sql|yaml|yml|toml|properties)$' | head -50)"
[ -z "$changed" ] && exit 0

# A Gradle build of this checkout would share build/ and produce false failures (wiki 2026-09-09 lesson). Gradle 9's
# wrapper runs 'java ... -jar <root>/gradle/wrapper/gradle-wrapper.jar', so match that path: the bare word gradlew
# also matched Claude Code's own shell wrapper, and other worktrees build into their own build/.
if pgrep -f "$ROOT/gradle/wrapper/gradle-wrapper.jar" >/dev/null 2>&1; then
  "$LOG" stop-gate skipped-concurrent-gradle "a Gradle build of this checkout is running"
  echo "stop-gate: a Gradle build of this checkout is running; skipped. Re-run ./scripts/check.sh when it finishes." >&2
  exit 0
fi

out="$("$ROOT/scripts/check.sh" 2>&1)"
code=$?
if [ $code -eq 0 ]; then exit 0; fi

"$LOG" stop-gate check.sh-failed "$(printf '%s' "$out" | grep -E 'RESULT|tests,|FAILED|error:' | tail -5)"
{
  echo "🛑 stop-gate: ./scripts/check.sh failed (exit $code). Fix before stopping. Last 40 lines (Gradle boilerplate is ~12, so the failing test name survives):"
  printf '%s\n' "$out" | tail -40
  echo "Order: spotlessApply → <module>/build/reports/detekt/<source set>.md → test-results XML → archTest rule name. Never weaken a test or rule to pass."
} >&2
exit 2
