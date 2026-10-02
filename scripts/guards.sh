#!/usr/bin/env bash
# guards.sh [<base> <head>] — constitution guards over what <head> adds since it left <base> (default origin/main..HEAD):
# diffs start at their merge-base, so files main gained after the fork never read as deleted. Fail-closed.
# Exit 0 = pass, 1 = violation, 2 = cannot judge (not a checkout, a ref that does not resolve or shares no history with
# the other, a failing git command). Each failure prints WHAT is wrong and HOW to fix it (an instruction to the agent).
set -uo pipefail
# Check pipelines end in a reader that consumes all input (grep ... >/dev/null, never grep -q): under pipefail an early
# exit kills the writer with SIGPIPE on a large diff or log, and a match would read as a miss.
# ROOT: the script's own checkout, else the working directory (CI runs the base commit's copy from outside the
# checkout). GIT_DIR is dropped for that lookup only: git exports it to hooks in a worktree, and with it set
# 'git -C <dir> rev-parse --show-toplevel' answers <dir> itself, so the event log path would point nowhere.
ROOT="$(env -u GIT_DIR -u GIT_WORK_TREE git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "guards: not inside a git checkout" >&2; exit 2; }
# GUARDS_LOGGER replaces the event logger: CI sets it to 'true', so the checkout's hook script (PR code) never runs there.
LOG="${GUARDS_LOGGER:-$ROOT/.claude/hooks/log-gate-event.sh}"
die() { echo "guards: $1" >&2; exit 2; }
BASE="${1:-refs/remotes/origin/main}"; HEAD_="${2:-HEAD}"
# No fallback base: the root commit made the range all of history and blamed files nobody touched.
for ref in "$BASE" "$HEAD_"; do
  git -C "$ROOT" rev-parse --verify -q "$ref^{commit}" >/dev/null || die "cannot resolve '$ref' — run: git fetch origin main"
done
RANGE="$BASE..$HEAD_"   # as given, for messages and git log (a log range already stops where the two histories meet)
BASE="$(git -C "$ROOT" merge-base "$BASE" "$HEAD_")" || die "$RANGE has no merge-base — run: git fetch origin main"
fail=0
violation() { echo "✖ $1"; echo "  → $2"; "$LOG" pre-push-guard "$3" "$1"; fail=1; }
# Content diffs are raw text whatever the repository says: a PR's '.gitattributes' with '*.kt -diff' (or a textconv,
# an external diff or color.diff=always) would otherwise hide added lines from checks 3, 6, 7 and 9.
DIFF=(--text --no-color --no-ext-diff --no-textconv)
# A trailer counts only with a reason after the colon ('Test-Change:' alone excuses nothing).
trailer() { printf '%s\n' "$messages" | grep -E "^$1:[[:space:]]*[^[:space:]]" >/dev/null; }

changed="$(git -C "$ROOT" diff --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
[ -z "$changed" ] && { echo "guards: empty range, pass"; exit 0; }
messages="$(git -C "$ROOT" log --format=%B "$RANGE")" || die "git log $RANGE failed"

# 1. Deleted test files without a Test-Change trailer (with the trailer the deletion is accepted and nothing is logged)
deleted="$(git -C "$ROOT" diff --diff-filter=D --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
deleted_tests="$(echo "$deleted" | grep -E 'src/(test|itest|archTest)/.*\.kt$' || true)"
if [ -n "$deleted_tests" ] && ! trailer Test-Change; then
  violation "test files deleted: $(echo "$deleted_tests" | tr '\n' ' ')" \
    "Restore them. If a test is genuinely obsolete, explain in the commit body and add the trailer 'Test-Change: <reason>'." deleted-test-file
elif [ -n "$deleted_tests" ]; then
  echo "  (Test-Change trailer present — deletion accepted)"
fi

# 2. Net assertion decrease without Test-Change trailer (git grep exits 1 when nothing matches; 2 or more is a failure)
count_asserts() {
  local out
  out="$(git -C "$ROOT" grep --text -c -E 'assertThat\(|assertThrows|assertThatThrownBy|assertTrue\(|assertFalse\(|assertEquals\(' "$1" -- '*/src/test/*' '*/src/itest/*' '*/src/archTest/*')"
  [ $? -le 1 ] || die "git grep $1 failed"
  printf '%s\n' "$out" | awk -F: '{s+=$NF} END {print s+0}'
}
before="$(count_asserts "$BASE")" || exit 2; after="$(count_asserts "$HEAD_")" || exit 2
if [ "$after" -lt "$before" ] && ! trailer Test-Change; then
  violation "assertions decreased $before → $after" "Restore the assertions, or justify with a 'Test-Change: <reason>' trailer." assertion-decrease
fi

# 3. New suppression in any Kotlin or Java source, tests included: @Suppress, @file:Suppress, @SuppressWarnings, @[Suppress(...)]
src_diff="$(git -C "$ROOT" diff "${DIFF[@]}" "$BASE" "$HEAD_" -- '*/src/*.kt' '*/src/*.java')" || die "git diff $RANGE failed"
if printf '%s\n' "$src_diff" | grep -E '^\+.*Suppress(Warnings)?\(' >/dev/null; then
  violation "new suppression under src/ (@Suppress, @file:Suppress, @SuppressWarnings or @[Suppress(...)])" "Fix the reported issue instead of suppressing it: a suppression hides findings in tests as much as in production code. The array form @[Suppress(...)] counts too: detekt honours it and ktfmt keeps it. If the rule is wrong, change config/detekt/detekt.yml in a harness ticket." new-suppress
fi

# 4. detekt baseline files (detekt 2.x names them per source set, e.g. detekt-baseline-main.xml)
if echo "$changed" | grep -E 'detekt-baseline[^/]*\.xml$' >/dev/null; then
  violation "detekt baseline file added" "Delete it. Baselines hide debt from the gates (CLAUDE.md Forbidden)." detekt-baseline
fi

# 5. Merged migrations edited (modified, not added)
modified="$(git -C "$ROOT" diff --diff-filter=M --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
edited_mig="$(echo "$modified" | grep -E 'db/migration/V.*\.sql$' || true)"
[ -n "$edited_mig" ] && violation "merged migration edited: $(echo "$edited_mig" | tr '\n' ' ')" \
  "Revert the edit and add a new V<yyyyMMdd>_<hhmm>__<slug>.sql that fixes forward." migration-edited

# 6. Hangul added to committed artifacts or written in the range's commit messages (English-only, D1) — README.ko.md
#    is the sole exception. Only lines the range adds count: a file that already holds Korean (Plan A embeds
#    README.ko.md) stays editable. awk tags each added line with its file ('+++ <path>' header; -M keeps a pure rename
#    free of added lines), grep matches. Portable byte-range match (macOS grep has no -P): UTF-8 lead bytes EA–ED cover
#    U+A000–U+D7FF incl. Hangul syllables; E3 84–86 the compatibility jamo; E1 84–87 the Hangul Jamo block.
HANGUL=$'([\xEA-\xED][\x80-\xBF][\x80-\xBF]|\xE3[\x84-\x86][\x80-\xBF]|\xE1[\x84-\x87][\x80-\xBF])'
added="$(git -C "$ROOT" diff "${DIFF[@]}" -M --no-prefix "$BASE" "$HEAD_" -- . ':(exclude)README.ko.md' ':(exclude)docs/research/')" \
  || die "git diff $RANGE failed"
hangul="$(printf '%s\n' "$added" \
  | LC_ALL=C awk '/^diff --git /{h=1} h && /^\+\+\+ /{f=substr($0, 5)} /^@@/{h=0} !h && /^\+/{print f "\t" $0}' \
  | LC_ALL=C grep -E $'\t\\+.*'"$HANGUL" | cut -f1 | sort -u || true)"
[ -n "$hangul" ] && violation "Korean text added in: $(echo "$hangul" | tr '\n' ' ')" \
  "Committed artifacts are English (ADR D1). Translate, or move the text to the owner's central wiki." non-english
if printf '%s\n' "$messages" | LC_ALL=C grep -E "$HANGUL" >/dev/null; then
  violation "Korean text in a commit message of $RANGE" \
    "Commit messages are English (ADR D1). Reword the commit (git commit --amend -F <file> for the last one)." non-english
fi

# 7. Secrets
all_diff="$(git -C "$ROOT" diff "${DIFF[@]}" "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
if printf '%s\n' "$all_diff" | grep -E '^\+' | grep -E 'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[0-9A-Za-z]{36,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|sk-ant-[A-Za-z0-9_-]{20,}' >/dev/null; then
  violation "secret-like literal added" "Remove it, rotate the credential, load it from the environment." secret-literal
fi

# 8. New production .kt without any test change in the range (test pair)
added_files="$(git -C "$ROOT" diff --diff-filter=A --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
new_prod="$(echo "$added_files" | grep -E 'src/main/kotlin/.*\.kt$' | grep -v -E 'Module\.kt$|package-info' || true)"
tests_touched="$(echo "$changed" | grep -E 'src/(test|itest|archTest)/' || true)"
if [ -n "$new_prod" ] && [ -z "$tests_touched" ]; then
  violation "new production Kotlin without tests: $(echo "$new_prod" | tr '\n' ' ')" \
    "Add the tests in this PR (DoD item 1). Every acceptance criterion maps to a test." missing-test-pair
fi

# 9. detekt touched outside the root build script: one module line (actions.clear(), which also drops
#    DetektGateGuard, enabled = false, setSource(files())) would switch the gate off and still exit 0.
gradle_diff="$(git -C "$ROOT" diff "${DIFF[@]}" "$BASE" "$HEAD_" -- '*.gradle.kts' ':(exclude)build.gradle.kts')" || die "git diff $RANGE failed"
detekt_lines="$(printf '%s\n' "$gradle_diff" | grep -E '^\+[^+]' | grep -E '[Dd]etekt' || true)"
[ -n "$detekt_lines" ] && violation "detekt configured outside the root build.gradle.kts: $(echo "$detekt_lines" | head -3 | tr '\n' ' ')" \
  "detekt is configured only in the root build.gradle.kts (Plan A Task 3); move the change there in a harness ticket." detekt-outside-root

if [ $fail -eq 0 ]; then echo "guards: pass ($RANGE)"; fi
exit $fail
