#!/usr/bin/env bash
# Exercises every project hook and gate script with real input. Run after any hook change. Exit 0 = all pass.
# Probes log to a temporary VERA_EVENTS_FILE and fixtures are throwaway repositories under one temp directory, so
# neither the real gate-event logs nor this working tree are touched.
set -uo pipefail
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
H="$ROOT/.claude/hooks"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export VERA_EVENTS_FILE="$T/events.jsonl"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
fail=0
ok()   { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }
last() { tail -1 "$VERA_EVENTS_FILE"; }
# fixture <dir>: a throwaway repository holding this checkout's hooks and scripts in one commit on main = origin/main.
fixture() {
  git init -q -b main "$1" && mkdir -p "$1/.claude" && cp -R "$H" "$1/.claude/" && cp -R "$ROOT/scripts" "$ROOT/.githooks" "$1/" \
    && git -C "$1" add -A && git -C "$1" commit -qm "base" && git -C "$1" update-ref refs/remotes/origin/main HEAD
}
# simulate <arg>: a 30 s background process whose command line holds <arg>; its pid lands in $sim.
simulate() { perl -e 'sleep 30' "$1" & sim=$!; for _ in $(seq 50); do pgrep -f "$1" >/dev/null && return; sleep 0.1; done; }

# log-gate-event writes one valid JSON line, masks secret-looking assignments only, and keeps the line ASCII (jq -a)
# even for a detail with invalid UTF-8 (the lone byte \xff becomes U+FFFD)
"$H/log-gate-event.sh" test-gate unit-test "hello world"
last | jq -e '.gate=="test-gate" and .rule=="unit-test" and (.ts|length)==20' >/dev/null && ok "log-gate-event json" || bad "log-gate-event json"
"$H/log-gate-event.sh" test-gate mask "PGPASSWORD=a GH_TOKEN=b API_KEY=c aws_secret_access_key=d --password=e --token=f --api-key=g"
[ "$(last | jq -r .detail)" = "PGPASSWORD=*** GH_TOKEN=*** API_KEY=*** aws_secret_access_key=*** --password=*** --token=*** --api-key=***" ] \
  && ok "log-gate-event masks secret-looking assignments" || bad "log-gate-event masks secret-looking assignments"
keep="RESULT check exit=1 seconds=3; git restore --source=HEAD x; git -c core.hooksPath=/dev/null push"
"$H/log-gate-event.sh" test-gate keep "$keep"
[ "$(last | jq -r .detail)" = "$keep" ] && ok "log-gate-event keeps other assignments readable" || bad "log-gate-event keeps other assignments readable"
"$H/log-gate-event.sh" test-gate non-ascii "$(printf 'caf\xc3\xa9 \xff')"
last | jq -e '.detail == "caf\u00e9 \ufffd"' >/dev/null && ! last | LC_ALL=C grep '[^ -~]' >/dev/null \
  && ok "log-gate-event escapes non-ASCII and invalid UTF-8" || bad "log-gate-event escapes non-ASCII and invalid UTF-8"
"$H/log-gate-event.sh" test-gate home "cat $HOME/x; PGPASSWORD=$HOME/y"
[ "$(last | jq -r .detail)" = "cat <home>/x; PGPASSWORD=***" ] && ok "log-gate-event writes \$HOME as <home>" || bad "log-gate-event writes \$HOME as <home>"

# Without VERA_EVENTS_FILE every worktree logs to one untracked file in the git common dir; detached HEAD logs 'detached'
F="$T/repo"; fixture "$F"
git -C "$F" checkout -q --detach && git -C "$F" worktree add -q -b wt "$T/wt"
env -u VERA_EVENTS_FILE "$F/.claude/hooks/log-gate-event.sh" test-gate shared "from the main checkout"
env -u VERA_EVENTS_FILE "$T/wt/.claude/hooks/log-gate-event.sh" test-gate shared "from a worktree"
jq -s -e 'map(.branch) == ["detached","wt"]' "$(git -C "$F" rev-parse --path-format=absolute --git-common-dir)/vera-events.jsonl" >/dev/null \
  && [ -z "$(git -C "$F" status --porcelain)$(git -C "$T/wt" status --porcelain)" ] \
  && ok "log-gate-event: one untracked log for every worktree" || bad "log-gate-event: one untracked log for every worktree"

# publish-events appends the valid lines the tracked file lacks, in order; a re-run adds nothing
printf '%s\n' '{"rule":"a"}' '{"rule":"b"}' '{"rule":"trunc' '{"rule":"c"}' > "$T/shared.jsonl"
mkdir -p "$F/.harness" && printf '%s' '{"rule":"a"}' > "$F/.harness/events.jsonl"   # no final newline
r1="$(VERA_EVENTS_FILE="$T/shared.jsonl" "$F/scripts/publish-events.sh")"; r2="$(VERA_EVENTS_FILE="$T/shared.jsonl" "$F/scripts/publish-events.sh")"
[ "$r1 | $r2" = "RESULT publish-events exit=0 added=2 | RESULT publish-events exit=0 added=0" ] \
  && [ "$(jq -r .rule "$F/.harness/events.jsonl" | tr '\n' ' ')" = "a b c " ] \
  && ok "publish-events: new valid lines in order, idempotent" || bad "publish-events: new valid lines in order, idempotent"

# inject-state emits hookSpecificOutput JSON with the Decisions of this checkout's wiki index
out="$(echo '{}' | "$H/inject-state.sh")"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="SessionStart"' >/dev/null && ok "inject-state json" || bad "inject-state json"
printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep 'Decisions' >/dev/null && ok "inject-state includes decisions" || bad "inject-state includes decisions"
# ... stops at the marker line, not at prose quoting the marker, and counts events around a truncated line
mkdir -p "$F/.harness/state"
printf '%s\n' '# Progress' 'Move old entries below the <!-- ARCHIVE --> line.' '## current entry' '<!-- ARCHIVE -->' '## archived entry' > "$F/.harness/state/progress.md"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "{\"ts\":\"$now\",\"gate\":\"g\",\"rule\":\"r\"}" '{"ts":"trunc' "{\"ts\":\"$now\",\"gate\":\"g\",\"rule\":\"r\"}" > "$T/inject.jsonl"
ctx="$(echo '{}' | VERA_EVENTS_FILE="$T/inject.jsonl" "$F/.claude/hooks/inject-state.sh" | jq -r .hookSpecificOutput.additionalContext)"
printf '%s\n' "$ctx" | grep -x '## current entry' >/dev/null && ! printf '%s\n' "$ctx" | grep -x '## archived entry' >/dev/null \
  && ok "inject-state: a quoted marker does not cut progress short" || bad "inject-state: a quoted marker does not cut progress short"
printf '%s\n' "$ctx" | grep -E '^ +2 g/r$' >/dev/null && ok "inject-state: a truncated event line hides nothing" || bad "inject-state: a truncated event line hides nothing"
# ... and reads the tracked copy when the shared log does not exist yet (fresh clone)
F2="$T/fresh"; fixture "$F2"; mkdir -p "$F2/.harness" && printf '%s\n' "{\"ts\":\"$now\",\"gate\":\"g\",\"rule\":\"tracked\"}" > "$F2/.harness/events.jsonl"
echo '{}' | env -u VERA_EVENTS_FILE "$F2/.claude/hooks/inject-state.sh" | jq -r .hookSpecificOutput.additionalContext | grep -E '^ +1 g/tracked$' >/dev/null \
  && ok "inject-state: fresh clone falls back to the tracked log" || bad "inject-state: fresh clone falls back to the tracked log"

# stop-gate: loop guard exits 0 immediately
echo '{"stop_hook_active": true}' | "$H/stop-gate.sh" >/dev/null 2>&1 && ok "stop-gate loop guard" || bad "stop-gate loop guard"
# stop-gate: clean tree exits 0 (skipped when this checkout has source changes: the gate would run the real check.sh)
if [ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all -- platform apps ingestion bootstrap build.gradle.kts settings.gradle.kts gradle config gradle.properties)" ]; then
  echo '{"stop_hook_active": false}' | "$H/stop-gate.sh" >/dev/null 2>&1 && ok "stop-gate clean tree" || bad "stop-gate clean tree"
else
  echo "SKIP stop-gate clean tree (working tree dirty)"
fi
# stop-gate in a fixture whose check.sh always fails: it sees a .kt file in a new package directory and a name with a
# space, and skips only while this checkout's wrapper jar runs, not for a process that merely names gradlew
G="$T/gate"; fixture "$G"; printf '#!/usr/bin/env bash\necho "RESULT format exit=1 seconds=0"\nexit 1\n' > "$G/scripts/check.sh"
gate() { echo '{"stop_hook_active": false}' | "$G/.claude/hooks/stop-gate.sh" >/dev/null 2>&1; echo $?; }
mkdir -p "$G/platform/m/src/main/kotlin/new/pkg" && : > "$G/platform/m/src/main/kotlin/new/pkg/New.kt"
[ "$(gate)" = 2 ] && ok "stop-gate sees a .kt file in a new package directory" || bad "stop-gate sees a .kt file in a new package directory"
rm -rf "$G/platform" && mkdir -p "$G/platform/a b" && : > "$G/platform/a b/C.kt"
[ "$(gate)" = 2 ] && ok "stop-gate sees a file name with a space" || bad "stop-gate sees a file name with a space"
simulate "$(git -C "$G" rev-parse --show-toplevel)/gradle/wrapper/gradle-wrapper.jar"   # physical path, as gradlew's pwd -P
[ "$(gate)" = 0 ] && last | jq -e '.rule=="skipped-concurrent-gradle"' >/dev/null \
  && ok "stop-gate skips while this checkout's wrapper jar runs" || bad "stop-gate skips while this checkout's wrapper jar runs"
kill "$sim"; wait "$sim" 2>/dev/null
simulate "gradlew GradleWrapperMain"
[ "$(gate)" = 2 ] && ok "stop-gate ignores a process that only names gradlew" || bad "stop-gate ignores a process that only names gradlew"
kill "$sim"; wait "$sim" 2>/dev/null

# format: ignores non-Kotlin files and exits 0
echo '{"tool_input":{"file_path":"'"$ROOT"'/README.md"}}' | "$H/format.sh" && ok "format ignores md" || bad "format ignores md"

# block-project-danger: blocks the destructive and hook-bypass patterns (exit 2), passes normal commands (exit 0),
# also behind git's global options ('git -C <path> ...', the form CLAUDE.md mandates).
for c in "./gradlew flywayClean" "docker compose down -v" "psql -c 'drop schema vera cascade'" "git checkout -- ." "git push --force origin main" \
         "git push --no-verify origin main" "git config core.hooksPath /dev/null" "git config --unset core.hooksPath" "git -c core.hooksPath=/dev/null push origin main" \
         "git -C $ROOT checkout -- ." "git -C $ROOT restore ." "git -C $ROOT push --force origin x" "git -C $ROOT push -f origin x" \
         "git checkout HEAD -- ." "git -C $ROOT restore --source=HEAD ." "git -C $ROOT push --no-verify origin x" "git -C $ROOT restore --staged ." \
         "git -C $ROOT reset --hard" "git -C $ROOT clean -fd" "git -C $ROOT clean --force" "git -C $ROOT push origin +x" \
         "git -C $ROOT push -fu origin x" "git -C $ROOT push -uf origin x" "git config 'core.hooksPath' /dev/null" "git -c 'core.hooksPath=/dev/null' push origin x"; do
  echo "{\"tool_input\":{\"command\":\"$c\"}}" | "$H/block-project-danger.sh" >/dev/null 2>&1
  [ $? -eq 2 ] && ok "block-project-danger blocks: $c" || bad "block-project-danger blocks: $c"
done
for c in "./scripts/check.sh" "git config core.hooksPath .githooks" "git config --get core.hooksPath" \
         "git -C $ROOT checkout -- docs/x.md" "git -C $ROOT checkout -- ./docs/x.md" "git -C $ROOT checkout -- .gitattributes" \
         "git -C $ROOT push origin x" "git -C $ROOT status" "git -C $ROOT config core.hooksPath .githooks" \
         "git -C $ROOT reset -q" "git -C $ROOT reset --soft HEAD~1" "git clean -n" "git push origin main"; do
  echo "{\"tool_input\":{\"command\":\"$c\"}}" | "$H/block-project-danger.sh" >/dev/null 2>&1 && ok "block-project-danger passes: $c" || bad "block-project-danger passes: $c"
done
# A pattern on the first line of a long multi-line command is still blocked: under pipefail, a reader that exits early
# (grep -q) would kill the writer with SIGPIPE once the input outgrows the pipe buffer, and the match would read as a miss.
long="git push --force origin x"$'\n'"$(seq -f 'echo padding line %g' 1 8000)"
jq -cn --arg c "$long" '{tool_input:{command:$c}}' | "$H/block-project-danger.sh" >/dev/null 2>&1
[ $? -eq 2 ] && ok "block-project-danger blocks: force push on line 1 of a >100 KB command" || bad "block-project-danger blocks: force push on line 1 of a >100 KB command"

# guards: current HEAD against itself must pass
"$ROOT/scripts/guards.sh" HEAD HEAD >/dev/null 2>&1 && ok "guards no-op range" || bad "guards no-op range"

# guards and pre-push in a fixture, offline: origin/main is a local ref and the remote a bare repository under $T.
# Secrets and Korean text are built from escapes at run time, so this file holds neither.
P="$T/guards"; fixture "$P"; git init -q --bare "$T/remote.git"; git -C "$P" config core.hooksPath .githooks
commit_in() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }
guards_last() { "$P/scripts/guards.sh" HEAD~1 HEAD 2>&1 || true; }   # output only: under pipefail a violation's exit 1 would fail the grep
out="$("$P/scripts/guards.sh" no-such-ref HEAD 2>&1)"
[ $? -eq 2 ] && printf '%s' "$out" | grep 'git fetch origin main' >/dev/null && ok "guards: a ref that does not resolve is exit 2" || bad "guards: a ref that does not resolve is exit 2"
mkdir -p "$T/nogit" && cp "$P/scripts/guards.sh" "$T/nogit/" && out="$(cd "$T/nogit" && ./guards.sh 2>&1)"
[ $? -eq 2 ] && printf '%s' "$out" | grep 'not inside a git checkout' >/dev/null && ok "guards: outside a checkout is exit 2" || bad "guards: outside a checkout is exit 2"
# A branch behind main is judged from the merge-base: a test main gained after the fork is not "deleted" by the branch
B="$T/behind"; fixture "$B"; git -C "$B" switch -q -c feature && printf 'x\n' > "$B/notes.txt" && commit_in "$B" "docs: notes"
git -C "$B" switch -q main && mkdir -p "$B/m/src/test/kotlin" && printf 'class N { fun n() = assertThat(1) }\n' > "$B/m/src/test/kotlin/N.kt" \
  && commit_in "$B" "test: N" && git -C "$B" update-ref refs/remotes/origin/main main
n="$(wc -l < "$VERA_EVENTS_FILE")"
"$B/scripts/guards.sh" origin/main feature >/dev/null 2>&1 && [ "$(wc -l < "$VERA_EVENTS_FILE")" = "$n" ] \
  && ok "guards: a branch behind main is judged from the merge-base" || bad "guards: a branch behind main is judged from the merge-base"
mkdir -p "$P/m/src/main/kotlin" && printf '*.kt -diff\n' > "$P/.gitattributes" && printf '@Suppress("X")\nclass A\n' > "$P/m/src/main/kotlin/A.kt"
commit_in "$P" "feat: a suppression behind -diff"
guards_last | grep 'new suppression' >/dev/null && ok "guards: '*.kt -diff' hides no added line" || bad "guards: '*.kt -diff' hides no added line"
mkdir -p "$P/m/src/test/kotlin" && printf 'class T { fun t() = assertThat(1) }\n' > "$P/m/src/test/kotlin/T.kt" && commit_in "$P" "test: add T"
git -C "$P" rm -q m/src/test/kotlin/T.kt && commit_in "$P" $'test: drop T\n\nTest-Change:'
guards_last | grep 'deleted-test-file in ' >/dev/null && ok "guards: 'Test-Change:' without a reason excuses nothing" || bad "guards: 'Test-Change:' without a reason excuses nothing"
git -C "$P" commit -q --amend -m $'test: drop T\n\nTest-Change: obsolete probe'
"$P/scripts/guards.sh" HEAD~1 HEAD >/dev/null 2>&1 && ok "guards: 'Test-Change: <reason>' accepts the deletion" || bad "guards: 'Test-Change: <reason>' accepts the deletion"
printf 'k = "%s"\n' "sk-ant-$(printf 'x%.0s' $(seq 24))" > "$P/k1.txt" && commit_in "$P" "chore: k1"
guards_last | grep 'secret-like literal' >/dev/null && ok "guards: an sk-ant- key is a secret" || bad "guards: an sk-ant- key is a secret"
printf 'k = "%s"\n' "github_pat_$(printf 'y%.0s' $(seq 24))" > "$P/k2.txt" && commit_in "$P" "chore: k2"
guards_last | grep 'secret-like literal' >/dev/null && ok "guards: a github_pat_ token is a secret" || bad "guards: a github_pat_ token is a secret"
printf 'jamo %s\n' "$(printf '\xe3\x84\xb1')" > "$P/j1.md" && commit_in "$P" "docs: j1"
guards_last | grep 'Korean text added' >/dev/null && ok "guards: compatibility jamo are Korean" || bad "guards: compatibility jamo are Korean"
printf 'jamo %s\n' "$(printf '\xe1\x84\x80')" > "$P/j2.md" && commit_in "$P" "docs: j2"
guards_last | grep 'Korean text added' >/dev/null && ok "guards: Hangul Jamo are Korean" || bad "guards: Hangul Jamo are Korean"
printf 'ok\n' > "$P/j3.md" && commit_in "$P" "docs: $(printf '\xed\x95\x9c')"
guards_last | grep 'Korean text in a commit message' >/dev/null && ok "guards: Korean in a commit message" || bad "guards: Korean in a commit message"
n="$(wc -l < "$VERA_EVENTS_FILE")"; printf '#!/usr/bin/env bash\necho "$*" >> "$GUARDS_OUT"\n' > "$T/logger" && chmod +x "$T/logger"
GUARDS_OUT="$T/logger.out" GUARDS_LOGGER="$T/logger" "$P/scripts/guards.sh" HEAD~1 HEAD >/dev/null 2>&1
grep '^pre-push-guard non-english' "$T/logger.out" >/dev/null && [ "$(wc -l < "$VERA_EVENTS_FILE")" = "$n" ] \
  && ok "guards: GUARDS_LOGGER replaces the event logger" || bad "guards: GUARDS_LOGGER replaces the event logger"
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/main >/dev/null 2>&1
[ $? -ne 0 ] && last | jq -e '.rule=="push-to-main"' >/dev/null && ok "pre-push refuses a push to main" || bad "pre-push refuses a push to main"
git -C "$P" update-ref refs/remotes/origin/main HEAD
printf 'x\n' > "$P/scripts/x.txt" && commit_in "$P" $'chore: touch scripts\n\nWiki-Skip:'
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/feature >/dev/null 2>&1
[ $? -ne 0 ] && last | jq -e '.rule=="blocked-no-wiki-change"' >/dev/null && ok "pre-push: 'Wiki-Skip:' without a reason does not pass" || bad "pre-push: 'Wiki-Skip:' without a reason does not pass"
git -C "$P" commit -q --amend -m $'chore: touch scripts\n\nWiki-Skip: probe, nothing decided'
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/feature >/dev/null 2>&1 && ok "pre-push: 'Wiki-Skip: <reason>' passes" || bad "pre-push: 'Wiki-Skip: <reason>' passes"
# The wiki gate also covers CI, the review contract, detekt config and the root build (neither ADR nor trailer here)
for f in .github/workflows/x.yml REVIEW.md config/detekt/x.yml settings.gradle.kts gradle/x.toml; do
  git -C "$P" switch -q -C wiki-gate refs/remotes/origin/main && mkdir -p "$P/$(dirname "$f")" && printf 'x\n' > "$P/$f" && commit_in "$P" "chore: touch $f"
  git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/wiki-gate >/dev/null 2>&1
  [ $? -ne 0 ] && last | jq -e '.rule=="blocked-no-wiki-change"' >/dev/null && ok "pre-push wiki gate covers $f" || bad "pre-push wiki gate covers $f"
done
git -C "$P" switch -q main
git -C "$P" worktree add -q "$T/pwt" -b wt-guards && printf '@Suppress("Y")\nclass B\n' > "$T/pwt/m/src/main/kotlin/B.kt" && commit_in "$T/pwt" "feat: B"
git -C "$T/pwt" push -q "$T/remote.git" HEAD:refs/heads/wt-guards >/dev/null 2>&1
[ $? -ne 0 ] && jq -s -e 'map(select(.branch=="wt-guards" and .rule=="new-suppress")) | length == 1' "$VERA_EVENTS_FILE" >/dev/null \
  && ok "guards log from a worktree (git exports GIT_DIR to hooks there)" || bad "guards log from a worktree (git exports GIT_DIR to hooks there)"

# Test weakening (ADR D10): guards judge every commit on its own, test source by test source, merges included
W="$T/weak"; fixture "$W"; K="$W/m/src/test/kotlin"; mkdir -p "$K" "$W/m/src/archTest/kotlin"
printf 'class T {\n    @Test fun a() { assertThat(1).isEqualTo(1) }\n    @Test fun b() { assertThat(2).isEqualTo(2) }\n}\n' > "$K/T.kt"
printf 'class U {\n    /**\n     * Checks three.\n     */\n    @Test fun u() { assertThat(3).isEqualTo(3) }\n}\n' > "$K/U.kt"
printf 'class A {\n    @ArchTest fun layers() { rule.check(classes) }\n    @ArchTest fun names() { other.check(classes) }\n}\n' > "$W/m/src/archTest/kotlin/A.kt"
printf 'import org.junit.jupiter.api.Disabled as Flaky;\nclass J {\n    @Test fun j() { assertThat(1) }\n}\ntypealias Off = org.junit.jupiter.api.Disabled\n' > "$K/J.kt"
mkdir -p "$W/m/src/test/java" && printf 'class JJ {\n    @Test void j() { assertThat(1); }\n}\n' > "$W/m/src/test/java/JJ.java"
printf 'class Kinds {\n    @ParameterizedTest fun p() {}\n    @RepeatedTest(2) fun r() {}\n    @TestFactory fun f() {}\n    @TestTemplate fun t() {}\n    @org.junit.jupiter.api.Test fun q() {}\n    @Test fun v() { modules.verify() }\n}\n' > "$K/Kinds.kt"
commit_in "$W" "test: base" && git -C "$W" update-ref refs/remotes/origin/main HEAD
on() { git -C "$W" switch -q -C "$1" refs/remotes/origin/main; }   # a fresh branch on the fixture's main
sha() { git -C "$W" rev-parse --short HEAD; }
# weak <name> <n> <text>...: guards over origin/main..HEAD refuse n times (0 = pass), log one event per refusal, print each <text>
weak() {
  local name="guards weakening: $1" n="$2" s; shift 2; : > "$T/w.events"
  out="$(GUARDS_OUT="$T/w.events" GUARDS_LOGGER="$T/logger" "$W/scripts/guards.sh" 2>&1)"; rc=$?
  [ "$rc" -eq "$((n > 0))" ] && [ "$(printf '%s\n' "$out" | grep -c '^✖')" -eq "$n" ] && [ "$(wc -l < "$T/w.events")" -eq "$n" ] \
    || { bad "$name (exit $rc)"; printf '%s\n' "$out"; return; }
  for s in "$@"; do printf '%s\n' "$out" | grep -F -- "$s" >/dev/null || { bad "$name (no '$s')"; printf '%s\n' "$out"; return; }; done
  ok "$name"
}
on g05; perl -pi -e 's/^class T/\@Disabled("flaky")\nclass T/' "$K/T.kt"; commit_in "$W" "test: park T"
weak "@Disabled on a test class (G05)" 1 "test-disabled in $(sha)" "T.kt skip markers 0 → 1" "Test-Change: <reason>"
on g04; perl -pi -e 's/\{ assertThat\(1\)/{ \/\/ assertThat(1)/; s/\{ (assertThat\(2\)[^ ]*)/{ println("\${"$1"}")/' "$K/T.kt"
perl -pi -e 's/\{ (assertThat\(3\)[^ ]*)/{ println("""\${"""$1"""}""")/' "$K/U.kt"; commit_in "$W" "test: comment out"
weak "assertions commented out or moved into a string template (G04)" 2 "assertion-decrease in $(sha)" "T.kt assertions 2 → 0" "U.kt assertions 1 → 0"
for m in '@DisabledOnOs(OS.MAC)' '@EnabledIf("x")' '@Ignore' 'assumeTrue(ok);' '@org.junit.jupiter.api.Disabled' '@ Disabled' '@[Tag("t") Disabled]' \
         '@field:[Disabled]' '@Flaky' '@Off' '@`Disabled`' '@org.junit.jupiter.api.`Disabled`' '`assumeTrue`(ok);'; do
  on skip; M="$m" perl -pi -e 's/\@Test fun j/$ENV{M} \@Test fun j/' "$K/J.kt"; commit_in "$W" "test: skip j"
  weak "a skip marker written $m" 1 "test-disabled in $(sha)" "J.kt skip markers 2 → 3"
done
for m in "@"$'\n'"    Disabled" "@org.junit.jupiter.api"$'\n'"        .Disabled"; do
  on jskip; M="$m" perl -pi -e 's/\@Test void j/$ENV{M} \@Test void j/' "$W/m/src/test/java/JJ.java"; commit_in "$W" "test: skip jj"
  weak "a Java skip marker split over lines: $(printf '%s' "$m" | tr -s '\n ' ' ')" 1 "test-disabled in $(sha)" "JJ.java skip markers 0 → 1"
done
for m in 'fun p' 'fun r' 'fun f' 'fun t' 'fun q'; do
  on kinds; M="$m" perl -ni -e 'print unless /\Q$ENV{M}\E/' "$K/Kinds.kt"; commit_in "$W" "test: drop $m"
  weak "a test case deleted: $m" 1 "test-case-decrease in $(sha)" "Kinds.kt test cases 6 → 5"
done
on verify; perl -pi -e 's/verify\(\)/toString()/' "$K/Kinds.kt"; commit_in "$W" "test: no verify"
weak "a .verify( assertion removed" 1 "assertion-decrease in $(sha)" "Kinds.kt assertions 1 → 0"
on g02; git -C "$W" mv m/src/test/kotlin/T.kt m/src/test/kotlin/T.kt.disabled; commit_in "$W" "test: rename T"
weak "a test renamed to *.kt.disabled (G02)" 1 "deleted-test-file in $(sha)" "moved out of the test sources to m/src/test/kotlin/T.kt.disabled"
on g03; mkdir -p "$W/m/src/test/resources/parked" && git -C "$W" mv m/src/test/kotlin/T.kt m/src/test/resources/parked/; commit_in "$W" "test: park T"
weak "a test moved to src/test/resources (G03)" 1 "deleted-test-file in $(sha)" "T.kt moved out"
on g07; perl -ni -e 'print unless /names/' "$W/m/src/archTest/kotlin/A.kt"; commit_in "$W" "test: drop a rule"
weak "an ArchUnit rule deleted (G07)" 2 "assertion-decrease in $(sha)" "A.kt assertions 2 → 1" "test-case-decrease in $(sha)"
on g06b; perl -pi -e 's/assertThat/println/' "$K/T.kt"; perl -pi -e 's/(isEqualTo\(3\))/$1; assertThat(1).isNotNull(); assertThat(2).isNotNull()/' "$K/U.kt"
commit_in "$W" "test: rebalance"; weak "losses in one file offset by gains in another (G06b)" 1 "assertion-decrease in $(sha)" "T.kt assertions 2 → 0"
on trailer2; perl -ni -e 'print unless /fun b/' "$K/T.kt"; commit_in "$W" $'test: drop b\n\nTest-Change: b repeats a'
perl -pi -e 's/assertThat/println/' "$K/U.kt"; commit_in "$W" "test: tidy U"
weak "an earlier commit's trailer excuses no later one (trailer2)" 1 "assertion-decrease in $(sha)" "accepted test-case-decrease"
on g08; perl -pi -e 's/assertThat/println/' "$K/U.kt"; commit_in "$W" "test: tidy U"; c1="$(sha)"
printf 'notes\n' > "$W/notes.md"; commit_in "$W" $'docs: notes\n\nTest-Change: unrelated'
weak "a trailer on an unrelated commit (G08)" 1 "assertion-decrease in $c1"
on side; perl -pi -e 's/assertThat/println/' "$K/U.kt"; commit_in "$W" "test: tidy U"; c1="$(sha)"
on g10; printf 'x\n' > "$W/x.md"; commit_in "$W" "docs: x"; git -C "$W" merge -q --no-ff -m $'Merge side\n\nTest-Change: merge' side
weak "a trailer on a merge commit (G10)" 1 "assertion-decrease in $c1"
on side; printf 'class V {\n    @Test fun v() { assertThat(4).isEqualTo(4) }\n}\n' > "$K/V.kt"; commit_in "$W" "test: V"
on evil; printf 'x\n' > "$W/x.md"; commit_in "$W" "docs: x"; git -C "$W" merge -q --no-ff --no-commit side >/dev/null 2>&1
perl -pi -e 's/assertThat\(2\)/println(2)/' "$K/T.kt"; git -C "$W" rm -q m/src/test/kotlin/U.kt
perl -pi -e 's/^class A/\@Disabled\nclass A/' "$W/m/src/archTest/kotlin/A.kt"; commit_in "$W" "Merge side"
weak "a merge losing an assertion, a test both parents kept, or adding a skip marker" 3 "assertion-decrease in $(sha)" \
  "T.kt assertions 2 → 1" "U.kt deleted" "test-disabled in $(sha)"
on side; perl -pi -e 's/^}/    \@Test fun x() { assertThat(7) }\n}/' "$K/U.kt"; commit_in "$W" "test: x"
on stacked2; git -C "$W" cherry-pick -x side >/dev/null && perl -pi -e 's/^}/    \@Test fun y() { assertThat(8) }\n}/' "$K/U.kt"
commit_in "$W" "test: y"; git -C "$W" merge -q --no-edit side >/dev/null 2>&1; git -C "$W" checkout -q --ours m/src/test/kotlin/U.kt
commit_in "$W" "Merge side"; weak "a conflict resolved keeping both sides (stacked branch)" 0
on addadd; perl -pi -e 's/^}/    \@Test fun z() { assertThat(9) }\n}/' "$K/U.kt"; commit_in "$W" "test: z"
git -C "$W" merge -q --no-edit side >/dev/null 2>&1; git -C "$W" checkout -q --ours m/src/test/kotlin/U.kt; commit_in "$W" "Merge side"
weak "a conflict resolved by dropping the other side's test" 2 "assertion-decrease in $(sha)" "U.kt assertions 3 → 2"
on side; perl -pi -e 's/^    \/\*\*$/    \/** Side./; s/isEqualTo\(3\)/isEqualTo(30)/' "$K/U.kt"; commit_in "$W" "test: u expects 30"
for evil in 0 1; do   # both sides edit the KDoc opening and the assertion; the merge keeps ours, with evil=1 it also drops u
  on modmod; perl -pi -e 's/^    \/\*\*$/    \/** Feat./; s/isEqualTo\(3\)/isEqualTo(31)/' "$K/U.kt"; commit_in "$W" "test: u expects 31"
  git -C "$W" merge -q --no-edit side >/dev/null 2>&1; git -C "$W" checkout -q --ours m/src/test/kotlin/U.kt
  [ $evil = 1 ] && perl -ni -e 'print unless /fun u/' "$K/U.kt"; commit_in "$W" "Merge side"
  [ $evil = 0 ] && weak "conflicts in a KDoc and an assertion resolved to one side" 0 || weak "the same merge dropping the test" 2 "U.kt assertions 1 → 0"
done
on side; git -C "$W" rm -q m/src/test/kotlin/U.kt; commit_in "$W" $'test: drop U\n\nTest-Change: U repeats T'
on moddel; perl -pi -e 's/isEqualTo\(3\)/isEqualTo(3); assertThat(4)/' "$K/U.kt"; commit_in "$W" "test: more u"
git -C "$W" merge -q --no-edit side >/dev/null 2>&1; git -C "$W" rm -q m/src/test/kotlin/U.kt; commit_in "$W" "Merge side"
weak "a modify/delete conflict resolved the deleting side's way" 0 "accepted deleted-test-file"
on side; git -C "$W" mv m/src/test/kotlin/T.kt m/src/test/kotlin/T2.kt; commit_in "$W" "test: rename T"
rw='class T {\n    @Test fun w() { assertThat(10) }\n    @Test fun x() { assertThat(11) }\n    @Test fun y() { assertThat(12) }\n}\n'
on rewrite; printf "$rw" > "$K/T.kt"; commit_in "$W" "test: rewrite T"; git -C "$W" merge -q --no-edit side >/dev/null 2>&1
weak "a merge carrying a rewrite across the other side's rename" 0
on rewrite2; printf "$rw" > "$K/T.kt"; commit_in "$W" "test: rewrite T"; git -C "$W" merge -q --no-commit side >/dev/null 2>&1
git -C "$W" checkout side -- m/src/test/kotlin/T2.kt; commit_in "$W" "Merge side"
weak "a merge dropping a rewrite carried across a rename" 2 "assertion-decrease in $(sha)" "T2.kt assertions 3 → 2"
git -C "$W" switch -q --orphan other && mkdir -p "$K" && printf 'class O {\n    @Test fun o() { assertThat(1) }\n}\n' > "$K/O.kt" && commit_in "$W" "test: O"
on unrelated; git -C "$W" merge -q --no-edit --allow-unrelated-histories other >/dev/null 2>&1; weak "a root commit merged from an unrelated history" 0
on side; perl -pi -e 's/(isEqualTo\(1\))/$1; assertThat(5).isEqualTo(5)/' "$K/T.kt"; commit_in "$W" "test: more a"
on stacked; git -C "$W" cherry-pick -x side >/dev/null && perl -pi -e 's/^}/    \@Test fun c() { assertThat(6) }\n}/' "$K/T.kt"
commit_in "$W" "test: c"; git -C "$W" merge -q --no-ff -m "Merge side" side >/dev/null 2>&1
weak "a merge of a change both sides made, one side then extending it (stacked branch)" 0
on moves; mkdir -p "$W/m/src/itest/java" && git -C "$W" mv m/src/test/kotlin/T.kt m/src/itest/java/; commit_in "$W" "test: move T"
weak "a test moved within the test sources" 0
on gains; perl -pi -e 's/^}/    \@Test fun c() { assertThat(5) } \/\/ \@Disabled assertThat(\n    val s = "\@Ignore assertThat(" \/* \@Disabled *\/\n}/' "$K/T.kt"
perl -pi -e 's/\{ assertThat\(1\)/{ val s = "\${m["k"] + "\x27"}"; assertThat(1)/' "$K/T.kt"
commit_in "$W" "test: c"; weak "gains, and skip markers named only in a comment or a string" 0
on tab; printf 'class X\n' > "$K/X$(printf '\t')Y.kt"; commit_in "$W" "test: X"; out="$("$W/scripts/guards.sh" 2>&1)"
[ $? -eq 2 ] && printf '%s\n' "$out" | grep 'tab or a newline' >/dev/null && ok "guards weakening: a path with a tab is exit 2" || bad "guards weakening: a path with a tab is exit 2"
on own; perl -pi -e 's/assertThat/println/' "$K/U.kt"; commit_in "$W" $'test: drop the U check\n\nTest-Change: U repeats T'
weak "the weakening commit's own trailer" 0 "accepted assertion-decrease"
on unreadable; perl -pi -e 's/a\(\)/a2()/' "$K/T.kt"; commit_in "$W" "test: rename a"
o="$(git -C "$W" rev-parse HEAD~1:m/src/test/kotlin/T.kt)"; rm -f "$W/.git/objects/${o:0:2}/${o:2}"   # breaks $W: keep last
out="$("$W/scripts/guards.sh" 2>&1)"
[ $? -eq 2 ] && printf '%s\n' "$out" | grep 'cannot read' >/dev/null && ok "guards weakening: an unreadable file is exit 2" || bad "guards weakening: an unreadable file is exit 2"

exit $fail
