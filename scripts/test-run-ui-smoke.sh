#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if bash scripts/run-ui-smoke.sh "$work/missing.app" > "$work/log" 2>&1; then
    echo "Missing app was accepted" >&2; exit 1
else
    [ "$?" -eq 1 ]
    grep -q 'Build the app first' "$work/log"
fi
if bash scripts/run-ui-smoke.sh one two > "$work/log" 2>&1; then
    echo "Extra arguments were accepted" >&2; exit 1
else
    [ "$?" -eq 2 ]
fi
python3 -m unittest discover -s UITests -p test_support.py
