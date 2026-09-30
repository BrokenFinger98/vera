#!/usr/bin/env bash
# Assemble the application jar without running tests (tests are check.sh / itest.sh).
# Callers: agents, CI build job.
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
[ $# -eq 0 ] || { echo "build.sh takes no arguments." >&2; exit 2; }
run_gradle build :bootstrap:bootJar
