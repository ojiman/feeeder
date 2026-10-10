#!/usr/bin/env bash
# Helpers for the `check` job in .github/workflows/ci.yml. The ruleset requires one status, `check`. It must report on
# every pull request, including documentation-only ones (where the macOS jobs are skipped) and failed or cancelled runs.
#
#   ci-gate.sh classify               Read changed file paths (one per line) from stdin. Print `true` when any path is
#                                     not documentation (docs/** or *.md), otherwise `false`. No input prints `true`,
#                                     so an empty or failed file list never skips the tests.
#   ci-gate.sh verdict CHANGES CODE VERIFY
#                                     CHANGES = result of the `changes` job, CODE = its `code` output,
#                                     VERIFY = result of the `verify` (macOS) jobs. Exit 0 only when the pull request may merge.
set -euo pipefail

case "${1:-}" in
  classify)
    code=false; any=false
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      any=true
      case "$path" in
        docs/*|*.md) ;;
        *) code=true ;;
      esac
    done
    if [ "$any" = false ]; then code=true; fi
    echo "$code"
    ;;
  verdict)
    changes=${2:?changes result}; code=${3:?code output}; verify=${4:?verify result}
    if [ "$changes" != success ]; then echo "check: the changes job ended with '$changes'" >&2; exit 1; fi
    case "$code:$verify" in
      false:skipped) echo "check: documentation only, macOS jobs skipped" ;;
      true:success)  echo "check: regression and release passed" ;;
      *) echo "check: code=$code, macOS jobs ended with '$verify'" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "usage: ci-gate.sh classify | verdict CHANGES CODE VERIFY" >&2; exit 2
    ;;
esac
