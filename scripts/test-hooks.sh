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

# log-gate-event writes one valid JSON line, masks NAME=value assignments, and keeps the line ASCII (jq -a) even
# for a detail with invalid UTF-8 (the lone byte \xff becomes U+FFFD)
"$H/log-gate-event.sh" test-gate unit-test "hello world"
last | jq -e '.gate=="test-gate" and .rule=="unit-test" and (.ts|length)==20' >/dev/null && ok "log-gate-event json" || bad "log-gate-event json"
"$H/log-gate-event.sh" test-gate mask "export API_KEY=abc123 then PASSWORD=x y"
[ "$(last | jq -r .detail)" = "export API_KEY=*** then PASSWORD=*** y" ] && ok "log-gate-event masks NAME=value" || bad "log-gate-event masks NAME=value"
"$H/log-gate-event.sh" test-gate non-ascii "$(printf 'caf\xc3\xa9 \xff')"
last | jq -e '.detail == "café �"' >/dev/null && ! last | LC_ALL=C grep '[^ -~]' >/dev/null \
  && ok "log-gate-event escapes non-ASCII and invalid UTF-8" || bad "log-gate-event escapes non-ASCII and invalid UTF-8"

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
mkdir -p "$P/m/src/main/kotlin" && printf '*.kt -diff\n' > "$P/.gitattributes" && printf '@Suppress("X")\nclass A\n' > "$P/m/src/main/kotlin/A.kt"
commit_in "$P" "feat: a suppression behind -diff"
guards_last | grep 'new suppression' >/dev/null && ok "guards: '*.kt -diff' hides no added line" || bad "guards: '*.kt -diff' hides no added line"
mkdir -p "$P/m/src/test/kotlin" && printf 'class T { fun t() = assertThat(1) }\n' > "$P/m/src/test/kotlin/T.kt" && commit_in "$P" "test: add T"
git -C "$P" rm -q m/src/test/kotlin/T.kt && commit_in "$P" $'test: drop T\n\nTest-Change:'
guards_last | grep 'test files deleted' >/dev/null && ok "guards: 'Test-Change:' without a reason excuses nothing" || bad "guards: 'Test-Change:' without a reason excuses nothing"
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
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/main >/dev/null 2>&1
[ $? -ne 0 ] && last | jq -e '.rule=="push-to-main"' >/dev/null && ok "pre-push refuses a push to main" || bad "pre-push refuses a push to main"
git -C "$P" update-ref refs/remotes/origin/main HEAD
printf 'x\n' > "$P/scripts/x.txt" && commit_in "$P" $'chore: touch scripts\n\nWiki-Skip:'
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/feature >/dev/null 2>&1
[ $? -ne 0 ] && last | jq -e '.rule=="blocked-no-wiki-change"' >/dev/null && ok "pre-push: 'Wiki-Skip:' without a reason does not pass" || bad "pre-push: 'Wiki-Skip:' without a reason does not pass"
git -C "$P" commit -q --amend -m $'chore: touch scripts\n\nWiki-Skip: probe, nothing decided'
git -C "$P" push -q "$T/remote.git" HEAD:refs/heads/feature >/dev/null 2>&1 && ok "pre-push: 'Wiki-Skip: <reason>' passes" || bad "pre-push: 'Wiki-Skip: <reason>' passes"
git -C "$P" worktree add -q "$T/pwt" -b wt-guards && printf '@Suppress("Y")\nclass B\n' > "$T/pwt/m/src/main/kotlin/B.kt" && commit_in "$T/pwt" "feat: B"
git -C "$T/pwt" push -q "$T/remote.git" HEAD:refs/heads/wt-guards >/dev/null 2>&1
[ $? -ne 0 ] && jq -s -e 'map(select(.branch=="wt-guards" and .rule=="new-suppress")) | length == 1' "$VERA_EVENTS_FILE" >/dev/null \
  && ok "guards log from a worktree (git exports GIT_DIR to hooks there)" || bad "guards log from a worktree (git exports GIT_DIR to hooks there)"

exit $fail
