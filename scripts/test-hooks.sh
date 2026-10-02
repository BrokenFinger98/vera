#!/usr/bin/env bash
# Exercises every project hook and gate script with real input. Run after any hook change. Exit 0 = all pass.
set -uo pipefail
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
H="$ROOT/.claude/hooks"
fail=0
ok()   { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }

# log-gate-event writes one valid JSON line with ticket parsed from branch
tmp="$(mktemp)"; cp "$ROOT/.harness/events.jsonl" "$tmp" 2>/dev/null || true
"$H/log-gate-event.sh" test-gate unit-test "hello world"
tail -1 "$ROOT/.harness/events.jsonl" | jq -e '.gate=="test-gate" and .rule=="unit-test" and (.ts|length)==20' >/dev/null && ok "log-gate-event json" || bad "log-gate-event json"
# remove the test line again
if [ -s "$tmp" ]; then cp "$tmp" "$ROOT/.harness/events.jsonl"; else : > "$ROOT/.harness/events.jsonl"; fi; rm -f "$tmp"

# inject-state emits hookSpecificOutput JSON
out="$(echo '{}' | "$H/inject-state.sh")"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName=="SessionStart"' >/dev/null && ok "inject-state json" || bad "inject-state json"
printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' | grep -q 'Decisions' && ok "inject-state includes decisions" || bad "inject-state includes decisions"

# stop-gate: loop guard exits 0 immediately
echo '{"stop_hook_active": true}' | "$H/stop-gate.sh" >/dev/null 2>&1 && ok "stop-gate loop guard" || bad "stop-gate loop guard"
# stop-gate: clean tree exits 0
if [ -z "$(git -C "$ROOT" status --porcelain -- platform apps ingestion bootstrap)" ]; then
  echo '{"stop_hook_active": false}' | "$H/stop-gate.sh" >/dev/null 2>&1 && ok "stop-gate clean tree" || bad "stop-gate clean tree"
else
  echo "SKIP stop-gate clean tree (working tree dirty)"
fi

# format: ignores non-Kotlin files and exits 0
echo '{"tool_input":{"file_path":"'"$ROOT"'/README.md"}}' | "$H/format.sh" && ok "format ignores md" || bad "format ignores md"

# block-project-danger: blocks the destructive and hook-bypass patterns (exit 2), passes normal commands (exit 0),
# also behind git's global options ('git -C <path> ...', the form CLAUDE.md mandates).
# Events written by these probes are discarded by restoring the backup (portable; macOS head has no negative -n).
bak="$(mktemp)"; cp "$ROOT/.harness/events.jsonl" "$bak" 2>/dev/null || : > "$bak"
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
cp "$bak" "$ROOT/.harness/events.jsonl"; rm -f "$bak"

# guards: current HEAD against itself must pass
"$ROOT/scripts/guards.sh" HEAD HEAD >/dev/null 2>&1 && ok "guards no-op range" || bad "guards no-op range"

exit $fail
