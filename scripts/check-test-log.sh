#!/usr/bin/env bash
# Reads the log of `swift test` (Swift Testing output) and fails when the run did not really finish, even if `swift test`
# exited with 0. It exists because a test process can end early with exit code 0 and no summary line (for example when a test
# stops the main run loop), and then CI shows a green job for tests that never ran.
#
#   check-test-log.sh LOGFILE
#
# It fails when:
#   - the log is missing or empty;
#   - a run has no summary line "Test run with N tests ..." (the run ended early);
#   - a line starts with "✘" (a failed test, suite or run);
#   - a test was started and did not end ("◇ Test ... started." without "✔/✘ Test ... passed/failed after").
set -euo pipefail

log=${1:?usage: check-test-log.sh LOGFILE}
if [ ! -s "$log" ]; then echo "check-test-log: '$log' is missing or empty" >&2; exit 1; fi

problems=0
fail() { echo "check-test-log: $1" >&2; problems=$((problems + 1)); }

# Every "Test run started." needs its own summary line: one `swift test` can start more than one run, and one of them can end early.
runs_started=$(grep -cE '^◇ Test run started\.$' "$log" || true)
runs_ended=$(grep -cE '^(✔|✘) Test run with [0-9]+ tests? in [0-9]+ suites? ' "$log" || true)
if [ "$runs_ended" -eq 0 ] || [ "$runs_ended" -ne "$runs_started" ]; then
  fail "$runs_started test run(s) started and $runs_ended 'Test run with ...' summary line(s): a test process ended before its run finished"
fi

failed=$(grep -E '^✘ ' "$log" || true)
if [ -n "$failed" ]; then
  fail "failures in the log:"
  printf '%s\n' "$failed" | head -n 20 >&2
fi

# Names of tests that started, and of those that ended. Lines about the run, a suite or one case of a parametrized test are not
# tests: a parametrized test prints one "Test case" line when each case starts, and one end line for the whole test.
started=$(grep -E '^◇ Test .* started\.$' "$log" | grep -vE '^◇ Test (run started\.|case )' \
  | sed -E 's/^◇ Test //; s/ started\.$//' | sort || true)
ended=$(grep -E '^(✔|✘) Test .* (passed|failed) after [0-9.]+ seconds' "$log" | grep -vE '^(✔|✘) Test run with ' \
  | sed -E 's/^(✔|✘) Test //; s/ (with [0-9]+ test cases )?(passed|failed) after [0-9.]+ seconds.*$//' | sort || true)
unfinished=$(comm -23 <(printf '%s\n' "$started") <(printf '%s\n' "$ended") | grep -v '^$' || true)
if [ -n "$unfinished" ]; then
  fail "tests that started and did not end ($(printf '%s\n' "$unfinished" | wc -l | tr -d ' ')):"
  printf '%s\n' "$unfinished" | head -n 20 | sed 's/^/  /' >&2
fi

if [ "$problems" -ne 0 ]; then exit 1; fi
echo "check-test-log: the run finished, with every started test ended and no failure"
