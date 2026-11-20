#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
output=$(mktemp)
trap 'rm -f "$output"' EXIT
status=0
"${GODOT:-godot}" --headless --path . --import >"$output" 2>&1 || status=$?
cat "$output"
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$output"; then exit 1; fi
exit "$status"
