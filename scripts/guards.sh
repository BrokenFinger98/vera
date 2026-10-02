#!/usr/bin/env bash
# guards.sh [<base> <head>] — constitution guards over a commit range (default origin/main..HEAD). Fail-closed.
# Exit 0 = pass. Each failure prints WHAT is wrong and HOW to fix it (the message is an instruction to the agent).
set -uo pipefail
# Check pipelines end in a reader that consumes all input (grep ... >/dev/null, never grep -q): under pipefail an early
# exit kills the writer with SIGPIPE on a large diff or log, and a match would read as a miss.
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel)"
LOG="$ROOT/.claude/hooks/log-gate-event.sh"
BASE="${1:-origin/main}"; HEAD_="${2:-HEAD}"
git -C "$ROOT" rev-parse --verify -q "$BASE" >/dev/null || BASE="$(git -C "$ROOT" rev-list --max-parents=0 "$HEAD_" | tail -1)"
RANGE="$BASE..$HEAD_"
fail=0
violation() { echo "✖ $1"; echo "  → $2"; "$LOG" pre-push-guard "$3" "$1"; fail=1; }

changed="$(git -C "$ROOT" diff --name-only "$BASE" "$HEAD_")"
[ -z "$changed" ] && { echo "guards: empty range, pass"; exit 0; }

# 1. Deleted test files without a Test-Change trailer (with the trailer the deletion is accepted and nothing is logged)
deleted_tests="$(git -C "$ROOT" diff --diff-filter=D --name-only "$BASE" "$HEAD_" | grep -E 'src/(test|itest|archTest)/.*\.kt$' || true)"
if [ -n "$deleted_tests" ] && ! git -C "$ROOT" log --format=%B "$RANGE" | grep '^Test-Change:' >/dev/null; then
  violation "test files deleted: $(echo "$deleted_tests" | tr '\n' ' ')" \
    "Restore them. If a test is genuinely obsolete, explain in the commit body and add the trailer 'Test-Change: <reason>'." deleted-test-file
elif [ -n "$deleted_tests" ]; then
  echo "  (Test-Change trailer present — deletion accepted)"
fi

# 2. Net assertion decrease without Test-Change trailer
count_asserts() { git -C "$ROOT" grep -c -E 'assertThat\(|assertThrows|assertThatThrownBy|assertTrue\(|assertFalse\(|assertEquals\(' "$1" -- '*/src/test/*' '*/src/itest/*' '*/src/archTest/*' 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}'; }
before="$(count_asserts "$BASE")"; after="$(count_asserts "$HEAD_")"
if [ "$after" -lt "$before" ] && ! git -C "$ROOT" log --format=%B "$RANGE" | grep '^Test-Change:' >/dev/null; then
  violation "assertions decreased $before → $after" "Restore the assertions, or justify with a 'Test-Change: <reason>' trailer." assertion-decrease
fi

# 3. New suppression in any Kotlin or Java source, tests included: @Suppress, @file:Suppress, @SuppressWarnings, @[Suppress(...)]
if git -C "$ROOT" diff "$BASE" "$HEAD_" -- '*/src/*.kt' '*/src/*.java' | grep -E '^\+.*Suppress(Warnings)?\(' >/dev/null; then
  violation "new suppression under src/ (@Suppress, @file:Suppress, @SuppressWarnings or @[Suppress(...)])" "Fix the reported issue instead of suppressing it: a suppression hides findings in tests as much as in production code. The array form @[Suppress(...)] counts too: detekt honours it and ktfmt keeps it. If the rule is wrong, change config/detekt/detekt.yml in a harness ticket." new-suppress
fi

# 4. detekt baseline files (detekt 2.x names them per source set, e.g. detekt-baseline-main.xml)
if echo "$changed" | grep -E 'detekt-baseline[^/]*\.xml$' >/dev/null; then
  violation "detekt baseline file added" "Delete it. Baselines hide debt from the gates (CLAUDE.md Forbidden)." detekt-baseline
fi

# 5. Merged migrations edited (modified, not added)
edited_mig="$(git -C "$ROOT" diff --diff-filter=M --name-only "$BASE" "$HEAD_" | grep -E 'db/migration/V.*\.sql$' || true)"
[ -n "$edited_mig" ] && violation "merged migration edited: $(echo "$edited_mig" | tr '\n' ' ')" \
  "Revert the edit and add a new V<yyyyMMdd>_<hhmm>__<slug>.sql that fixes forward." migration-edited

# 6. Hangul added to committed artifacts (English-only, D1) — README.ko.md is the sole exception.
#    Only lines the range adds count: a file that already holds Korean (Plan A embeds README.ko.md) stays editable.
#    awk tags each added line with its file ('+++ <path>' header; -M keeps a pure rename free of added lines), grep matches.
#    Portable byte-range match (macOS grep has no -P): UTF-8 lead bytes EA–ED cover U+A000–U+D7FF incl. Hangul syllables.
hangul="$(git -C "$ROOT" diff -M --no-prefix "$BASE" "$HEAD_" -- . ':(exclude)README.ko.md' ':(exclude)docs/research/' \
  | LC_ALL=C awk '/^diff --git /{h=1} h && /^\+\+\+ /{f=substr($0, 5)} /^@@/{h=0} !h && /^\+/{print f "\t" $0}' \
  | LC_ALL=C grep -E $'\t\\+.*[\xEA-\xED][\x80-\xBF][\x80-\xBF]' | cut -f1 | sort -u || true)"
[ -n "$hangul" ] && violation "Korean text added in: $(echo "$hangul" | tr '\n' ' ')" \
  "Committed artifacts are English (ADR D1). Translate, or move the text to the owner's central wiki." non-english

# 7. Secrets
if git -C "$ROOT" diff "$BASE" "$HEAD_" | grep -E '^\+' | grep -E 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[0-9A-Za-z]{36,}|xox[baprs]-[0-9A-Za-z-]{10,}' >/dev/null; then
  violation "secret-like literal added" "Remove it, rotate the credential, load it from the environment." secret-literal
fi

# 8. New production .kt without any test change in the range (test pair)
new_prod="$(git -C "$ROOT" diff --diff-filter=A --name-only "$BASE" "$HEAD_" | grep -E 'src/main/kotlin/.*\.kt$' | grep -v -E 'Module\.kt$|package-info' || true)"
tests_touched="$(echo "$changed" | grep -E 'src/(test|itest|archTest)/' || true)"
if [ -n "$new_prod" ] && [ -z "$tests_touched" ]; then
  violation "new production Kotlin without tests: $(echo "$new_prod" | tr '\n' ' ')" \
    "Add the tests in this PR (DoD item 1). Every acceptance criterion maps to a test." missing-test-pair
fi

# 9. detekt touched outside the root build script: one module line (actions.clear(), which also drops
#    DetektGateGuard, enabled = false, setSource(files())) would switch the gate off and still exit 0.
detekt_lines="$(git -C "$ROOT" diff "$BASE" "$HEAD_" -- '*.gradle.kts' ':(exclude)build.gradle.kts' | grep -E '^\+[^+]' | grep -E '[Dd]etekt' || true)"
[ -n "$detekt_lines" ] && violation "detekt configured outside the root build.gradle.kts: $(echo "$detekt_lines" | head -3 | tr '\n' ' ')" \
  "detekt is configured only in the root build.gradle.kts (Plan A Task 3); move the change there in a harness ticket." detekt-outside-root

if [ $fail -eq 0 ]; then echo "guards: pass ($RANGE)"; fi
exit $fail
