#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
bash tools/check.sh
output=$(mktemp)
trap 'rm -f "$output"' EXIT
status=0
"${GODOT:-godot}" --headless --path . --script res://tests/run_tests.gd >"$output" 2>&1 || status=$?
cat "$output"
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$output"; then exit 1; fi
exit "$status"
