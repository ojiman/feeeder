#!/bin/bash
# Control-flow tests for fetch-ci-app.sh with stubbed gh/ditto/codesign/xattr.
# Needs neither macOS, network nor a real gh. It does not test macOS behavior:
# whether `gh` really leaves no quarantine attribute is checked by running the script itself.
set -uo pipefail
cd "$(dirname "$0")/.."
script=${FETCH_SCRIPT:-scripts/fetch-ci-app.sh}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bin=$work/bin; mkdir -p "$bin"
head_sha=aaaaaaa1111111111111111111111111111111aa

cat > "$bin/gh" <<'EOF'
#!/bin/bash
case "$1 $2" in
  "pr view") echo "${FAKE_HEAD:-aaaaaaa1111111111111111111111111111111aa}" ;;
  "run list") [ -n "${FAKE_NORUN:-}" ] || echo 12345 ;;
  "run download")
    while [ $# -gt 0 ]; do [ "$1" = "--dir" ] && d=$2; shift; done
    mkdir -p "$d/unagi-reader-release-x"; : > "$d/unagi-reader-release-x/UnagiReader-adhoc.zip"
    printf 'commit\npr_head=%s\nmacOS\n' "${FAKE_BUILT:-aaaaaaa1111111111111111111111111111111aa}" > "$d/unagi-reader-release-x/environment.txt" ;;
esac
EOF
cat > "$bin/ditto" <<'EOF'
#!/bin/bash
for last; do :; done; mkdir -p "$last/${FAKE_APP_NAME:-Unagi Reader.app}"
EOF
cat > "$bin/codesign" <<'EOF'
#!/bin/bash
for last; do :; done
[ -d "$last" ]
EOF
cat > "$bin/xattr" <<'EOF'
#!/bin/bash
if [ -n "${FAKE_XFAIL:-}" ]; then echo "xattr: [Errno 1] Operation not permitted" >&2; exit 1; fi
[ -n "${FAKE_Q:-}" ] && echo "com.apple.quarantine: 0083;abc"
exit 0
EOF
chmod +x "$bin"/*

export UNAGI_READER_CI_ROOT=$work/out
failures=0
# run_case NAME EXPECTED_EXIT MUST_MATCH MUST_NOT_MATCH [ENV=VALUE ...] -- ARGS...
run_case() {
    local name=$1 want_code=$2 must=$3 must_not=$4; shift 4
    local envs=() out code
    while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
    out=$(env PATH="$bin:$PATH" ${envs[@]+"${envs[@]}"} bash "$script" "$@" 2>&1); code=$?
    local ok=1
    [ "$code" -eq "$want_code" ] || ok=0
    printf '%s' "$out" | grep -Eq -- "$must" || ok=0
    if [ -n "$must_not" ] && printf '%s' "$out" | grep -Eq -- "$must_not"; then ok=0; fi
    if [ "$ok" -eq 1 ]; then echo "ok   $name"; else echo "FAIL $name (exit $code, wanted $want_code)"; printf '%s\n' "$out" | sed 's/^/     | /'; failures=$((failures + 1)); fi
    rm -rf "$UNAGI_READER_CI_ROOT"
}

run_case "PR happy path"                 0 'Ready: .*no quarantine attribute' 'WARNING|Artifact was built' -- 10
run_case "--run happy path"              0 'Ready: '                          'WARNING'                      -- --run 999
run_case "older artifact"                0 'Ready: .*UnagiReader.app'         'WARNING' FAKE_APP_NAME=UnagiReader.app -- --run 998
run_case "built for another head"        1 'Artifact was built for'           'Ready:'  FAKE_BUILT=bbbbbbb2222222222222222222222222222222bb -- 10
run_case "no successful CI run"          1 'No successful CI run'             'Ready:'  FAKE_NORUN=1 -- 10
run_case "quarantine attribute present"  1 'WARNING: .*com.apple.quarantine'  'Ready:'  FAKE_Q=1 -- 10
run_case "xattr read failure is not 'no attribute'" 1 'Operation not permitted' 'Ready:|no quarantine attribute' FAKE_XFAIL=1 -- 10
for bad in "" abc "--run" "--run x"; do
    # shellcheck disable=SC2086
    run_case "bad arguments: '$bad'"     2 'Usage:'                           'Ready:' -- $bad
done

# An existing output directory must not be reused.
env PATH="$bin:$PATH" bash "$script" 10 >/dev/null 2>&1
out=$(env PATH="$bin:$PATH" bash "$script" 10 2>&1); code=$?
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q 'already exists'; then echo "ok   existing output directory is refused"; else echo "FAIL existing output directory (exit $code)"; failures=$((failures + 1)); fi

[ "$failures" -eq 0 ] && echo "all passed" || { echo "$failures failed"; exit 1; }
