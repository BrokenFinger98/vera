#!/usr/bin/env bash
# PostToolUse(Edit|Write) — format the touched Kotlin file with ktfmt via Spotless. Never blocks (check.sh verifies).
set -uo pipefail
INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)"
case "$FILE" in *.kt|*.kts) ;; *) exit 0 ;; esac
[ -f "$FILE" ] || exit 0
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
case "$FILE" in "$ROOT"/*) ;; *) exit 0 ;; esac
if pgrep -f 'GradleWrapperMain|gradlew' >/dev/null 2>&1; then exit 0; fi   # never fight a running build
"$ROOT/gradlew" -p "$ROOT" -q --console=plain spotlessApply -PspotlessIdeHook="$FILE" >/dev/null 2>&1 || true
exit 0
