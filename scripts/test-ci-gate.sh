#!/usr/bin/env bash
# Control-flow tests for scripts/ci-gate.sh. Needs only bash.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
gate="$here/ci-gate.sh"
failures=0

expect_value() { # name expected actual
  local name=$1 expected=$2 actual=$3
  if [ "$actual" = "$expected" ]; then echo "ok   $name"; else echo "FAIL $name: expected '$expected', got '$actual'"; failures=$((failures + 1)); fi
}
expect_status() { # name expected-status command...
  local name=$1 expected=$2; shift 2
  "$@" >/dev/null 2>&1; local status=$?
  if [ "$status" -eq "$expected" ]; then echo "ok   $name"; else echo "FAIL $name: expected exit $expected, got $status"; failures=$((failures + 1)); fi
}
classify() { printf '%s' "$1" | bash "$gate" classify; }

expect_value "docs only"                    false "$(classify $'docs/a.md\ndocs/decisions/b.md\n')"
expect_value "root markdown only"           false "$(classify $'README.md\nAGENTS.md\n')"
expect_value "any source file"              true  "$(classify $'docs/a.md\nSources/RSSReader/ReaderView.swift\n')"
expect_value "workflow change is code"      true  "$(classify $'.github/workflows/ci.yml\n')"
expect_value "script change is code"        true  "$(classify $'scripts/build-app.sh\n')"
expect_value "non-docs file named like md"  true  "$(classify $'Sources/notes.txt\n')"
expect_value "empty list never skips"       true  "$(classify '')"
expect_value "blank lines only never skip"  true  "$(classify $'\n\n')"

expect_status "docs only, jobs skipped"      0 bash "$gate" verdict success false skipped
expect_status "code, jobs passed"            0 bash "$gate" verdict success true success
expect_status "code, jobs failed"            1 bash "$gate" verdict success true failure
expect_status "code, jobs cancelled"         1 bash "$gate" verdict success true cancelled
expect_status "code, jobs skipped"           1 bash "$gate" verdict success true skipped
expect_status "docs only but jobs failed"    1 bash "$gate" verdict success false failure
expect_status "changes job failed"           1 bash "$gate" verdict failure true skipped
expect_status "changes job cancelled"        1 bash "$gate" verdict cancelled false skipped
expect_status "missing arguments"            1 bash "$gate" verdict success
expect_status "unknown command"              2 bash "$gate" nope

if [ "$failures" -ne 0 ]; then echo "$failures test(s) failed"; exit 1; fi
echo "all gate tests passed"
