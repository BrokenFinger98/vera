#!/usr/bin/env bash
# Re-measures the calibrated detekt limits; run it on every detekt version bump (Plan A Task 3).
# Enables the fixtures under platform/metadata/.../poc/calibration (one probe just inside and one
# just outside every limit), runs :platform:metadata:detektMain and compares the findings in its
# markdown report with EXPECTED below. Not part of check.sh: the outside fixtures fail by design.
# Callers: whoever bumps detekt.
# Exit codes: 0 boundaries unchanged · 1 boundary drift or Gradle failure · 2 environment (not a repo, not bash, bad arguments).
. "$(dirname "$0")/lib.sh"
[ $# -eq 0 ] || { echo "detekt-calibrate.sh takes no arguments." >&2; exit 2; }

CAL="$ROOT/platform/metadata/src/main/kotlin/com/brokenfinger/vera/metadata/poc/calibration"
REPORT="$ROOT/platform/metadata/build/reports/detekt/main.md"
LOG="$ROOT/build/detekt-calibrate.log"
# Every finding the outside fixtures must produce, as "rule file"; the inside fixtures stay silent.
EXPECTED="CyclomaticComplexMethod CyclomaticComplexMethodOutside.kt
LargeClass LargeObjectOutside.kt
LongMethod LongMethodOutside.kt
LongParameterList LongParameterListOutside.kt
LongParameterList LongParameterListOutside.kt
NestedBlockDepth NestedBlockDepthOutside.kt
TooManyFunctions TooManyClassOutside.kt
TooManyFunctions TooManyEnumOutside.kt
TooManyFunctions TooManyInterfaceOutside.kt
TooManyFunctions TooManyObjectOutside.kt
TooManyFunctions TooManyTopLevelOutside.kt"

# Enabled fixtures would fail check.sh, so every exit path renames them back.
disable_fixtures() {
  local f
  for f in "$CAL"/*/*.kt; do
    [ -e "$f" ] && mv "$f" "$f.disabled"
  done
}
trap disable_fixtures EXIT
trap 'exit 130' INT TERM
for f in "$CAL"/*/*.kt.disabled; do
  [ -e "$f" ] && mv "$f" "${f%.disabled}"
done

start=$SECONDS
rm -f "$REPORT"
mkdir -p "$(dirname "$LOG")"
# detektMain fails here by design; its report, not its exit code, is what gets compared.
"$ROOT/gradlew" -p "$ROOT" --console=plain -q :platform:metadata:detektMain >"$LOG" 2>&1
actual="$([ -f "$REPORT" ] && awk '/^### /{rule=$3} /^\* (Error|Warning|Info): /{split($3, loc, ":"); n=split(loc[1], dirs, "/"); print rule, dirs[n]}' "$REPORT" | sort)"
expected="$(printf '%s\n' "$EXPECTED" | sort)"
code=0
[ "$actual" = "$expected" ] || code=1
echo "RESULT calibrate exit=${code} seconds=$((SECONDS - start))"
if [ $code -ne 0 ]; then
  echo "detekt-calibrate.sh: findings differ from the calibrated boundaries (< expected, > actual):" >&2
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") >&2
  echo "Adjust config/detekt/detekt.yml until this passes; never edit the fixtures. Gradle output: build/detekt-calibrate.log" >&2
fi
exit $code
