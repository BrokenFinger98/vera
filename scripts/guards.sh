#!/usr/bin/env bash
# guards.sh [<base> <head>] — constitution guards over what <head> adds since it left <base> (default origin/main..HEAD):
# diffs start at their merge-base, so files main gained after the fork never read as deleted; checks 1-2 judge each
# commit of the range on its own. Fail-closed.
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

commits="$(git -C "$ROOT" rev-list --reverse "$RANGE")" || die "git rev-list $RANGE failed"
[ -z "$commits" ] && { echo "guards: empty range, pass"; exit 0; }
changed="$(git -C "$ROOT" diff --name-only "$BASE" "$HEAD_")" || die "git diff $RANGE failed"
messages="$(git -C "$ROOT" log --format=%B "$RANGE")" || die "git log $RANGE failed"

# 1-2. Test weakening, judged per commit and per test source (ADR D10). Every commit of the range, merges included, must
#    leave each test source (.kt or .java under src/{test,itest,archTest}/{kotlin,java}/) where it was, with as many
#    assertions (assert…( .check( .verify() and test cases (@Test and its kin) as it was given and no new skip marker
#    (@Disabled… @Enabled… @Ignore assume…() — unless that commit's own message carries 'Test-Change: <reason>' (a reason
#    after the colon; 'Test-Change:' alone excuses nothing). A commit is given its parent's version; a merge what
#    'git merge-file' makes of its parents' changes, or ours + theirs - base where that conflicts.
TS='(^|/)src/(test|itest|archTest)/(kotlin|java)/.*[.](kt|java)$'
EMPTY="$(git -C "$ROOT" hash-object -t tree /dev/null)" || die "git hash-object failed"
TMP="$(mktemp -d)" || die "mktemp failed"; trap 'rm -rf "$TMP"' EXIT
# SCAN prints "<assertions> <test cases> <skip markers>" of one file, counted after blanking comments (nested in Kotlin),
# strings, raw strings, char literals and backtick names.
IFS= read -r -d '' SCAN <<'AWK'
function hits(s, re, word,    k) {
  for (k = 0; match(s, re); s = substr(s, RSTART + RLENGTH))
    if (!word || RSTART == 1 || substr(s, RSTART - 1, 1) !~ /[A-Za-z0-9_]/) k++
  return k
}
{
  line = $0; n = length(line); code = ""
  for (i = 1; i <= n; ) {
    two = substr(line, i, 2); c = substr(line, i, 1)
    if (depth) { if (two == "*/") { depth--; i += 2 } else if (kt && two == "/*") { depth++; i += 2 } else i++ }
    else if (raw) { if (substr(line, i, 3) == "\"\"\"") { raw = 0; for (i += 3; substr(line, i, 1) == "\""; ) i++ } else i++ }
    else if (two == "//") break
    else if (two == "/*") { depth = 1; i += 2; code = code " " }
    else if (substr(line, i, 3) == "\"\"\"") { raw = 1; i += 3; code = code " " }
    else if (c == "\"" || c == "\047" || c == "`") {
      for (i++; i <= n && substr(line, i, 1) != c; i++) if (c != "`" && substr(line, i, 1) == "\\") i++
      i++; code = code " "
    } else { code = code c; i++ }
  }
  code = code " "
  a += hits(code, "assert[A-Za-z0-9_]*[ \t]*[(<{]", 1) + hits(code, "\\.(check|verify)[ \t]*\\(", 0)
  t += hits(code, "@(Test|ParameterizedTest|RepeatedTest|TestFactory|TestTemplate|ArchTest)[^A-Za-z0-9_]", 0)
  s += hits(code, "@(Disabled|Enabled)[A-Za-z0-9_]*|@Ignore[^A-Za-z0-9_]", 0) + hits(code, "assume[A-Za-z0-9_]*[ \t]*\\(", 1)
}
END { print a + 0, t + 0, s + 0 }
AWK
# JOIN reads the diffs of one commit against each parent (tag 1..k) and, for a merge, against the merge base (tag 0).
# It prints "F <path> <blob> <given blob>..." per test source the commit changes (the base's version first for a merge,
# '-' = absent) and "D <path> <old blob> <new path or ->" per test source it drops that no other parent deleted.
IFS= read -r -d '' JOIN <<'AWK'
BEGIN { FS = OFS = "\t" }
$2 != "D" && $4 ~ ts { from[$1, $4] = ($2 == "A" || $3 !~ ts) ? "-" : $5; if ($1) now[$4] = $6 }
($2 == "D" || $2 == "R") && $3 ~ ts { had[$1, $3] = $5; if ($1 && ($2 == "D" || $4 !~ ts)) out[$3] = ($2 == "D") ? "-" : $4 }
END {
  for (f in now) { r = "F" OFS f OFS now[f]; for (t = (k > 1) ? 0 : 1; t <= k; t++) r = r OFS (((t, f) in from) ? from[t, f] : now[f]); print r }
  for (g in out) {
    kept = 1; if (k > 1 && ((0, g) in had)) for (t = 1; t <= k; t++) if (!((t, g) in had)) kept = 0
    for (t = 1; kept && t <= k; t++) if ((t, g) in had) { print "D", g, had[t, g], out[g]; kept = 0 }
  }
}
AWK
# entries <tag> <from> <to>: the rename-aware diff, one tab-separated line per path: tag, status, old path, new path,
# old blob, new blob
entries() {
  local tag="$1"
  git -C "$ROOT" diff-tree -r -M -z --no-abbrev "$2" "$3" | while IFS= read -r -d '' meta && IFS= read -r -d '' p; do
    q="$p"; case "$meta" in *' R'*) IFS= read -r -d '' q ;; esac
    set -- $meta; printf '%s\t%.1s\t%s\t%s\t%s\t%s\n' "$tag" "$5" "$p" "$q" "$3" "$4"
  done
}
blob() { if [ "$1" = - ]; then : > "$2"; else git -C "$ROOT" cat-file blob "$1" > "$2" || die "cannot read $3 (blob $1) of commit $c"; fi; }
count() {   # count <file> <path>: sets A N S
  local kt=0; case "$2" in *.kt) kt=1 ;; esac
  LC_ALL=C awk -v kt="$kt" "$SCAN" "$1" > "$TMP/n" || die "cannot count $2 of commit $c"; read -r A N S < "$TMP/n"
}
# expect <path> <blob>...: sets EA EN ES, the counts <path> must keep. One blob: the parent's version. The base's, then
# each parent's: their merge-file result, or ours + theirs - base when merge-file conflicts.
expect() {
  local f="$1" k=$(($# - 2)) p first=1 clean=1; shift
  blob "$1" "$TMP/base" "$f"; count "$TMP/base" "$f"; EA=$A EN=$N ES=$S; shift
  [ "$k" -eq 0 ] && return
  EA=$((EA * (1 - k))) EN=$((EN * (1 - k))) ES=$((ES * (1 - k)))
  for p in "$@"; do
    blob "$p" "$TMP/other" "$f"; count "$TMP/other" "$f"; EA=$((EA + A)) EN=$((EN + N)) ES=$((ES + S))
    if [ "$first" -eq 1 ]; then cp "$TMP/other" "$TMP/acc"; first=0; continue; fi
    git -C "$ROOT" merge-file -q "$TMP/acc" "$TMP/base" "$TMP/other" >/dev/null 2>&1 || clean=0
  done
  [ "$clean" -eq 1 ] && { count "$TMP/acc" "$f"; EA=$A EN=$N ES=$S; }
}
weakened() {   # weakened <rule> <what>: a violation, or a note when the commit carries the trailer
  if [ "$excused" -eq 1 ]; then echo "  ($where carries Test-Change: accepted $1, $2)"; return; fi
  violation "$1 in $where: $2" "Restore the test in that commit, or give that very commit the trailer 'Test-Change: <reason>' (the reason in its body) before pushing; git commit --amend if it is the last. A trailer on another commit, or a later commit that restores the test, does not count." "$1"
}
for c in $commits; do
  parents="$(git -C "$ROOT" rev-list --parents -n 1 "$c")" && msg="$(git -C "$ROOT" log -1 --format=%B "$c")" \
    && where="$(git -C "$ROOT" log -1 --format='%h "%s"' "$c")" || die "cannot read commit $c"
  excused=0; printf '%s\n' "$msg" | grep -E '^Test-Change:[[:space:]]*[^[:space:]]' >/dev/null && excused=1
  set -- ${parents#"$c"}; [ $# -eq 0 ] && set -- "$EMPTY"   # a root commit is compared with the empty tree
  t=0; : > "$TMP/e"
  for p in "$@"; do t=$((t + 1)); entries "$t" "$p" "$c" >> "$TMP/e" || die "cannot diff commit $c against $p"; done
  if [ $# -gt 1 ]; then
    base="$(git -C "$ROOT" merge-base --octopus "$@")" || base="$EMPTY"
    entries 0 "$base" "$c" >> "$TMP/e" || die "cannot diff commit $c against $base"
  fi
  LC_ALL=C awk -v k=$# -v ts="$TS" "$JOIN" "$TMP/e" | LC_ALL=C sort > "$TMP/r" || die "cannot judge commit $c"
  while IFS=$'\t' read -r kind f b rest <&3; do
    blob "$b" "$TMP/x" "$f"; count "$TMP/x" "$f"
    if [ "$kind" = D ]; then
      [ "$rest" = - ] && rest=deleted || rest="moved out of the test sources to $rest"
      weakened deleted-test-file "$f $rest (assertions $A → 0, test cases $N → 0)"; continue
    fi
    a=$A n=$N s=$S; expect "$f" $rest
    [ "$a" -lt "$EA" ] && weakened assertion-decrease "$f assertions $EA → $a"
    [ "$n" -lt "$EN" ] && weakened test-case-decrease "$f test cases $EN → $n"
    [ "$s" -gt "$ES" ] && weakened test-disabled "$f skip markers $ES → $s"
  done 3< "$TMP/r"
done

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
