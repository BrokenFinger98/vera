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

# 1-2. Test weakening, judged per commit and per test source (ADR D10). Every commit of the range must leave each test
#    source (.kt or .java under src/{test,itest,archTest}/{kotlin,java}/) where it was, with as many assertions
#    (assert…( .check( .verify() and test cases (@Test and its kin) as it was given and no new skip marker
#    (@Disabled… @Enabled… @Ignore assume…(), in any spelling — unless that commit's own message carries
#    'Test-Change: <reason>' (a reason after the colon; 'Test-Change:' alone excuses nothing). A commit is given its
#    parent's version; a merge what git merge-tree makes of its two parents, where a conflict hunk counts ours +
#    theirs - base.
TS='(^|/)src/(test|itest|archTest)/(kotlin|java)/.*[.](kt|java)$'
EMPTY="$(git -C "$ROOT" hash-object -t tree /dev/null)" || die "git hash-object failed"
TMP="$(mktemp -d)" || die "mktemp failed"; trap 'rm -rf "$TMP"' EXIT
# SCAN prints "<assertions> <test cases> <skip markers>" of one file, read twice: the first pass collects the Kotlin
# aliases it declares (import … as Y, typealias Y = …), the second counts. It blanks comments (nested in Kotlin),
# strings and raw strings (Kotlin templates ${…} stay code), char literals and backtick names other than plain
# identifiers; reads annotations in any spelling (@ X, @[X Y], @field:X, @org.junit.X, split over lines); and counts
# aliasing a skip marker as one.
IFS= read -r -d '' SCAN <<'AWK'
BEGIN { asserts = "assert[A-Za-z0-9_]*"; tests = "Test|ParameterizedTest|RepeatedTest|TestFactory|TestTemplate|ArchTest"
        skips = "(Disabled|Enabled)[A-Za-z0-9_]*|Ignore"; assumes = "assume[A-Za-z0-9_]*" }
function hits(s, re, word,    k) {
  for (k = 0; match(s, re); s = substr(s, RSTART + RLENGTH))
    if (!word || RSTART == 1 || substr(s, RSTART - 1, 1) !~ /[A-Za-z0-9_]/) k++
  return k
}
function tpl(s, i,    n, d, ch) {   # s[i] starts a Kotlin template ${…}: the index after its closing brace
  n = length(s); d = 1; i += 2
  while (i <= n && d) { ch = substr(s, i, 1); if (ch == "\"") { i = skip(s, i, ch); continue } d += (ch == "{") - (ch == "}"); i++ }
  return i
}
function skip(s, i, q,    n, ch) {   # s[i] opens a string or a backtick name q: the index after it
  for (n = length(s); ++i <= n; ) {
    ch = substr(s, i, 1)
    if (ch == q) return i + 1
    if (q == "`") continue
    if (ch == "\\") i++
    else if (kt && substr(s, i, 2) == "${") i = tpl(s, i) - 1
  }
  return i
}
function alias(name, as) {   # pass 1 records an alias; pass 2 counts one that names a skip marker
  if (name ~ /^(Disabled|Enabled)/ || name == "Ignore") { if (pass == 1) skips = skips "|" as; else cs++ }
  else if (name ~ /^assume/) { if (pass == 1) assumes = assumes "|" as; else cs++ }
  else if (pass > 1) return
  else if (name ~ /^(Test|ParameterizedTest|RepeatedTest|TestFactory|TestTemplate|ArchTest)$/) tests = tests "|" as
  else if (name ~ /^assert/) asserts = asserts "|" as
}
function norm(code,    x) {   # annotations in any spelling become @Name
  gsub(/@[ \t]+/, "@", code); while (gsub(/@[A-Za-z_][A-Za-z0-9_]*[ \t]*[.:][ \t]*/, "@", code)) ;
  while (match(code, /@\[[^]]*\]/)) { x = substr(code, RSTART + 2, RLENGTH - 3); gsub(/[^ \t]+/, "@&", x); code = substr(code, 1, RSTART - 1) " " x " " substr(code, RSTART + RLENGTH) }
  while (gsub(/@[A-Za-z_][A-Za-z0-9_]*[ \t]*[.:][ \t]*/, "@", code)) ;
  return code
}
function tally(code) {
  code = code " "
  ca += hits(code, "(" asserts ")[ \t]*[(<{]", 1) + hits(code, "\\.(check|verify)[ \t]*\\(", 0)
  ct += hits(code, "@(" tests ")[^A-Za-z0-9_]", 0)
  cs += hits(code, "@(" skips ")[^A-Za-z0-9_]", 0) + hits(code, "(" assumes ")[ \t]*\\(", 1)
}
FNR == 1 { pass++; depth = raw = 0; pend = "" }
{
  line = $0; n = length(line); code = ""
  for (i = 1; i <= n; ) {
    two = substr(line, i, 2); c = substr(line, i, 1)
    if (depth) { if (two == "*/") { depth--; i += 2 } else if (kt && two == "/*") { depth++; i += 2 } else i++ }
    else if (raw) { if (substr(line, i, 3) == "\"\"\"") { raw = 0; for (i += 3; substr(line, i, 1) == "\""; ) i++ } else if (kt && two == "${") i = tpl(line, i); else i++ }
    else if (two == "//") break
    else if (two == "/*") { depth = 1; i += 2; code = code " " }
    else if (substr(line, i, 3) == "\"\"\"") { raw = 1; i += 3; code = code " " }
    else if (c == "\"") { i = skip(line, i, c); code = code " " }
    else if (c == "`") { j = skip(line, i, c); x = substr(line, i + 1, j - i - 2); code = code ((x ~ /^[A-Za-z_][A-Za-z0-9_]*$/) ? x : " "); i = j }
    else if (c == "'" && match(substr(line, i, 9), /^'(\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]|\\.|[^'\\])'/)) { i += RLENGTH; code = code " " }
    else { code = code c; i++ }
  }
  if (pend != "") code = pend " " code   # an annotation that ends a line is read with the next one
  pend = ""; if (match(code, /@[ \t]*([A-Za-z_][A-Za-z0-9_]*([ \t]*[.:][ \t]*[A-Za-z_][A-Za-z0-9_]*)*[ \t]*[.:]?)?[ \t]*$/)) { pend = substr(code, RSTART); code = substr(code, 1, RSTART - 1) }
  code = norm(code); x = code; sub(/^[ \t]+/, "", x); sub(/[ \t;]+$/, "", x); m = split(x, w, /[ \t.=;]+/)
  if (w[1] == "import" && m > 3 && w[m - 1] == "as") alias(w[m - 2], w[m]); else if (w[1] == "typealias" && m > 2) alias(w[m], w[2])
  if (pass > 1) tally(code)
}
END { if (pend != "") tally(norm(pend)); print ca + 0, ct + 0, cs + 0 }
AWK
# JOIN turns the diff of a commit against what it was given into "F <path> <blob> <given blob or -> <given path>" per
# test source it changes and "D <path> <old blob> <new path or -> <path>" per test source it drops or moves out.
IFS= read -r -d '' JOIN <<'AWK'
BEGIN { FS = OFS = "\t" }
$1 != "D" && $3 ~ ts { print "F", $3, $5, (($1 == "A" || $2 !~ ts) ? "-" : $4), $2 }
($1 == "D" || $1 == "R" && $3 !~ ts) && $2 ~ ts { print "D", $2, $4, (($1 == "D") ? "-" : $3), $2 }
AWK
# UNMARK splits a file merge-tree left conflicted (zdiff3 markers, CRLF too) into whole ours, base and theirs versions
UNMARK='{ l = $0; sub(/\r$/, "", l) }
substr(l, 1, 8) == "<<<<<<< " { sec = 1; next }
substr(l, 1, 8) == "||||||| " { sec = 2; next }
l == "=======" && sec { sec = 3; next }
substr(l, 1, 8) == ">>>>>>> " { sec = 0; next }
sec != 2 && sec != 3 { print > ours }
sec != 1 && sec != 3 { print > base }
sec != 1 && sec != 2 { print > theirs }'
# entries <from> <to>: the rename-aware diff, one tab-separated line per path: status, old path, new path, old blob, new blob
entries() {
  git -C "$ROOT" diff-tree -r -M -z --no-abbrev "$1" "$2" | while IFS= read -r -d '' meta && IFS= read -r -d '' p; do
    q="$p"; case "$meta" in *' R'*) IFS= read -r -d '' q ;; esac
    case "$p$q" in *$'\t'*|*$'\n'*) die "a path holds a tab or a newline, rename it: $p" ;; esac
    set -- $meta; printf '%.1s\t%s\t%s\t%s\t%s\n' "$5" "$p" "$q" "$3" "$4"
  done
}
blob() { if [ "$1" = - ]; then : > "$2"; else git -C "$ROOT" cat-file blob "$1" > "$2" || die "cannot read $3 (blob $1) of $where"; fi; }
count() {   # count <file> <path>: sets A N S, the language following <path>
  local kt=0; case "$2" in *.kt) kt=1 ;; esac
  LC_ALL=C awk -v kt="$kt" "$SCAN" "$1" "$1" > "$TMP/n" || die "cannot count $2 of $where"; read -r A N S < "$TMP/n"
}
# side_deleted <path>: the merge base holds <path> and a parent does not — one side deleted it, so may the merge
side_deleted() {
  [ -n "$mb" ] && git -C "$ROOT" cat-file -e "$mb:$1" 2>/dev/null \
    && { ! git -C "$ROOT" cat-file -e "$P1:$1" 2>/dev/null || ! git -C "$ROOT" cat-file -e "$P2:$1" 2>/dev/null; }
}
weakened() {   # weakened <rule> <what>: a violation, or a note when the commit carries the trailer
  if [ "$excused" -eq 1 ]; then echo "  ($where carries Test-Change: accepted $1, $2)"; return; fi
  violation "$1 in $where: $2" "Restore the test in that commit, or give that very commit the trailer 'Test-Change: <reason>' (the reason in its body) before pushing; git commit --amend if it is the last. A trailer on another commit, or a later commit that restores the test, does not count." "$1"
}
for c in $commits; do
  parents="$(git -C "$ROOT" rev-list --parents -n 1 "$c")" && msg="$(git -C "$ROOT" log -1 --format=%B "$c")" \
    && where="$(git -C "$ROOT" log -1 --format='%h "%s"' "$c")" || die "cannot read commit $c"
  excused=0; printf '%s\n' "$msg" | grep -E '^Test-Change:[[:space:]]*[^[:space:]]' >/dev/null && excused=1
  set -- ${parents#"$c"}; given="${1:-$EMPTY}"; : > "$TMP/conflicted"   # a root commit is given the empty tree
  [ $# -le 2 ] || die "$where merges $# parents; guards judge two at most: merge one branch at a time"
  if [ $# -eq 2 ]; then   # in-tree .gitattributes (a merge driver) must not shape the merge it is judged against
    P1="$1" P2="$2"; mb="$(git -C "$ROOT" merge-base "$1" "$2")" || mb=""
    git --attr-source="$EMPTY" -C "$ROOT" -c merge.conflictStyle=zdiff3 merge-tree --write-tree --allow-unrelated-histories -z --name-only "$1" "$2" > "$TMP/mt"
    [ $? -le 1 ] || die "cannot merge the parents of $where again"
    { IFS= read -r -d '' given; while IFS= read -r -d '' p && [ -n "$p" ]; do printf '%s\n' "$p"; done; } < "$TMP/mt" > "$TMP/conflicted"
  fi
  entries "$given" "$c" | LC_ALL=C awk -v ts="$TS" "$JOIN" | LC_ALL=C sort > "$TMP/r" || die "cannot diff $where"
  while IFS=$'\t' read -r kind f b g src <&3; do
    blob "$b" "$TMP/x" "$f"; count "$TMP/x" "$f"; a=$A n=$N s=$S
    if [ "$kind" = D ]; then
      [ $# -eq 2 ] && side_deleted "$f" && continue   # a modify/delete conflict, resolved the deleting side's way
      [ "$g" = - ] && g=deleted || g="moved out of the test sources to $g"
      weakened deleted-test-file "$f $g (assertions $a → 0, test cases $n → 0)"; continue
    fi
    blob "$g" "$TMP/p" "$src"; count "$TMP/p" "$src"; EA=$A EN=$N ES=$S
    if grep -Fx -- "$src" "$TMP/conflicted" >/dev/null; then   # conflicted: ours + theirs - base, each a whole file
      : > "$TMP/o"; : > "$TMP/b"; : > "$TMP/t"
      LC_ALL=C awk -v ours="$TMP/o" -v base="$TMP/b" -v theirs="$TMP/t" "$UNMARK" "$TMP/p" || die "cannot split $src of $where"
      count "$TMP/o" "$src"; EA=$A EN=$N ES=$S; count "$TMP/t" "$src"; EA=$((EA + A)) EN=$((EN + N)) ES=$((ES + S))
      count "$TMP/b" "$src"; EA=$((EA - A)) EN=$((EN - N)) ES=$((ES - S))
    fi
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
