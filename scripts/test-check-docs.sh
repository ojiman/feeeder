#!/usr/bin/env bash
# Runs the tests of scripts/check_docs.py. Needs only bash and Python 3.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
python3 "$here/test_check_docs.py"
