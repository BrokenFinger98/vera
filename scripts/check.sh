#!/usr/bin/env bash
# Fast quality gate: formatting, detekt, unit tests, architecture tests. No Docker.
# Callers: Stop hook (.claude/hooks/stop-gate.sh) and CI. Exit 0 means "safe to stop".
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
[ $# -eq 0 ] || { echo "check.sh takes no arguments; use ./scripts/test.sh :module:path to scope tests." >&2; exit 2; }

# Spotless invalidates the configuration cache on every .kt edit, so it runs in its own invocation
# and the detekt/test cache entry stays warm (Task 3 quality review).
run_gradle format spotlessCheck || { code=$?; echo "check.sh: formatting failed — run ./gradlew spotlessApply, then rerun." >&2; exit $code; }

# One detekt task per source set, all four with type resolution and all on `check`.
# UnsafeCallOnNullableType (`!!`) checks production sources only; tests may use `!!`.
# detektItest compiles the itest sources but does not run them, so no Docker.
run_gradle check detektMain detektTest detektItest detektArchTest test archTest
code=$?
if [ $code -ne 0 ]; then
  echo "check.sh failed. detekt: build/reports/detekt/*.md · tests: build/test-results/<suite>/ (assertion printed above) · archTest: fix the code, not the rule." >&2
fi
exit $code
