#!/usr/bin/env bash
# PreToolUse(Bash) — Vera-specific destructive commands and git-hook bypasses, on top of the global block-danger.sh. exit 2 = blocked.
set -uo pipefail
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)"
[ -n "$CMD" ] || exit 0
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || exit 0
LOG="$ROOT/.claude/hooks/log-gate-event.sh"

# The patterns below read NORM: the command with git's global options stripped ('git -C <path> push' → 'git push';
# CLAUDE.md mandates -C) and quotes dropped. One option per pass, those taking a value first, until none is left.
# hooks_path_values reads $CMD itself, because 'git -c core.hooksPath=...' is one of the stripped options.
GIT_OPT_ARG="(-[Cc]|--(git-dir|work-tree|namespace|config-env|attr-source))[[:space:]]+(\"[^\"]*\"|'[^']*'|[^[:space:];&|]+)"
NORM="$(printf '%s' "$CMD" | sed -E -e ':a' -e "s/(git)[[:space:]]+$GIT_OPT_ARG/\1/g" -e 'ta' \
  -e 's/(git)[[:space:]]+-[^[:space:];&|]*/\1/g' -e 'ta' -e "s/[\"']//g")"

block() {
  "$LOG" block-danger "$2" "$CMD"
  echo "🚫 blocked: $1" >&2
  echo "   command: $CMD" >&2
  echo "   $3" >&2
  exit 2
}
m() { printf '%s' "$NORM" | grep -qiE "$1"; }
# Values the command gives core.hooksPath ('git config ... core.hooksPath V', 'git -c core.hooksPath=V'; the key may be quoted).
# A read gives none; the fd number of a redirect after a read ('core.hooksPath 2>/dev/null') is dropped.
hooks_path_values() {
  printf '%s' "$CMD" | grep -oiE "config([[:space:]]+[^[:space:];&|]+)*[[:space:]]+[\"']?core\.hookspath[\"']?[[:space:]]+[^[:space:];&|<>()]+|-c[[:space:]]+[\"']?core\.hookspath=[^[:space:];&|<>()]*" \
    | sed -E "s/.*[=[:space:]]//; s/[\"']//g" | grep -vxE '[0-9]+'
}

m 'flyway(Clean|Repair)|flyway[[:space:]]+(clean|repair)' && block "Flyway clean/repair" flyway-clean "Migrations are immutable; fix forward with a new V<timestamp>__*.sql."
m 'compose[[:space:]]+down.*(-v|--volumes)' && block "compose down with volumes" compose-down-volumes "Volumes hold the demo database; use 'docker compose down' without -v."
m 'drop[[:space:]]+schema' && block "DROP SCHEMA" drop-schema "Schema changes go through Flyway migrations reviewed in a PR."
m 'git[[:space:]]+(checkout|restore)([[:space:]]+[^[:space:];&|]+)*[[:space:]]+(\./?|:/)([[:space:];&|]|$)' && block "discarding all working-tree changes" git-discard-all "Discard single files by path, never the whole tree; to unstage everything, use 'git reset -q'."
# reset --hard and clean -f repeat global block-danger.sh rules, which need git next to the subcommand and so miss 'git -C <path>'.
m 'git[[:space:]]+reset([[:space:]]+[^[:space:];&|]+)*[[:space:]]+--hard([[:space:];&|]|$)' && block "git reset --hard" reset-hard "It drops uncommitted work; commit or stash it instead ('git reset -q' only unstages)."
m 'git[[:space:]]+clean([[:space:]]+[^[:space:];&|]+)*[[:space:]]+(-[[:alnum:]]*f[[:alnum:]]*|--force)([[:space:];&|]|$)' && block "git clean with --force" clean-force "It deletes untracked files for good; remove single paths instead, after a dry run with 'git clean -n'."
# Force push: --force* (incl. --force-with-lease), a short-flag cluster with f (-f, -fu, -uf) or a +<refspec>.
m 'git[[:space:]]+push([[:space:]]+[^[:space:];&|]+)*[[:space:]]+(--force[^[:space:];&|]*|-[[:alnum:]]*f[[:alnum:]]*|\+[^[:space:];&|]+)([[:space:];&|]|$)' && block "force push" force-push "History is linear and protected; open a new commit instead."
m 'git[[:space:]].*--no-verify([^-[:alnum:]]|$)' && block "skipping git hooks with --no-verify" no-verify "The guards are fail-closed; fix the code instead of skipping them."
m 'unset[^;&|]*core\.hookspath' && block "unsetting core.hooksPath" hooks-path "core.hooksPath installs the push gate; it stays .githooks."
hooks_path_values | grep -vx '\.githooks' >/dev/null && block "core.hooksPath other than .githooks" hooks-path "core.hooksPath installs the push gate; only 'git config core.hooksPath .githooks' is allowed."
exit 0
