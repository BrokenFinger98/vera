#!/usr/bin/env bash
[ -n "${BASH_VERSION:-}" ] || { echo "scripts/*.sh require bash, not sh." >&2; exit 2; }
# Shared helpers. Source only from scripts/*.sh (bash).
# Exit codes across the scripts: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
set -uo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)" || ROOT=""
if [ -z "$ROOT" ] || [ ! -x "$ROOT/gradlew" ]; then
  echo "lib.sh: repository root not found from $(dirname "${BASH_SOURCE[0]}") (not a git checkout, or gradlew missing)." >&2
  echo "RESULT bootstrap exit=2 seconds=0"
  exit 2
fi
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home}"

# run_gradle <label> <gradle args...> — runs Gradle, prints the result line, returns its exit code.
run_gradle() {
  local label="$1"; shift
  local start=$SECONDS
  "$ROOT/gradlew" -p "$ROOT" --console=plain -q "$@"
  local code=$?
  echo "RESULT ${label} exit=${code} seconds=$((SECONDS - start))"
  return $code
}
