#!/usr/bin/env bash
# Integration tests with Testcontainers (needs Docker). Pass a module path to scope.
# Callers: agents, CI itest job.
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
if ! docker info >/dev/null 2>&1; then
  echo "RESULT itest exit=3 seconds=0"
  echo "Docker unavailable (daemon down or CLI missing). Start Docker, then rerun. Integration tests never fall back to H2." >&2
  exit 3
fi
if [ $# -gt 0 ]; then run_gradle itest "$1:itest"; else run_gradle itest itest; fi
