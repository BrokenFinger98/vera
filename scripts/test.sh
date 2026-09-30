#!/usr/bin/env bash
# Unit tests only. Pass a module path to scope: ./scripts/test.sh :platform:metadata
# Callers: agents scoping a module.
# Exit codes: 0 ok · 1 Gradle failure · 2 environment (not a repo, not bash, bad arguments) · 3 Docker unavailable.
. "$(dirname "$0")/lib.sh"
if [ $# -gt 0 ]; then run_gradle test "$1:test"; else run_gradle test test; fi
