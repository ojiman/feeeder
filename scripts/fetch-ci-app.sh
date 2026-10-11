#!/bin/bash
# Fetch the ad hoc signed Release app that CI built for a pull request, without a browser.
# Files saved by a browser get com.apple.quarantine, and an app that is not notarized is then
# blocked by Gatekeeper on every new build. `gh` does not add that attribute.
#
# Usage: fetch-ci-app.sh <PR number>
#        fetch-ci-app.sh --run <workflow run id>
# A pull request run builds the app only when the PR changes how the app is built or packaged (see AGENTS.md).
# For any other branch, start the workflow by hand and pass its run id with --run, or build locally.
# Needs macOS (ditto, codesign, xattr) and an authenticated, recent `gh` (`run download --pattern`)
# run inside this repository. UNAGI_READER_CI_ROOT overrides the output root (scripts/test-fetch-ci-app.sh uses it).
set -euo pipefail

usage() { echo "Usage: fetch-ci-app.sh <PR number> | --run <workflow run id>" >&2; exit 2; }
for tool in gh ditto codesign xattr find; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool (this script needs macOS and an authenticated gh)" >&2; exit 1; }
done

expected_head=""
case "${1:-}" in
    --run) [ "$#" -eq 2 ] && [[ "$2" =~ ^[0-9]+$ ]] || usage; run_id=$2; label=run-$2 ;;
    ''|-*) usage ;;
    *)
        [ "$#" -eq 1 ] && [[ "$1" =~ ^[0-9]+$ ]] || usage
        expected_head=$(gh pr view "$1" --json headRefOid --jq .headRefOid)
        run_id=$(gh run list --workflow ci.yml --commit "$expected_head" --status success --limit 1 --json databaseId --jq '.[0].databaseId // empty')
        [ -n "$run_id" ] || { echo "No successful CI run for PR #$1 at ${expected_head:0:7}. Wait for CI, or check the PR." >&2; exit 1; }
        label=pr-$1-${expected_head:0:7} ;;
esac

dest=${UNAGI_READER_CI_ROOT:-/private/tmp/unagi-reader-ci}/$label
[ ! -e "$dest" ] || { echo "$dest already exists; remove it or use another run." >&2; exit 1; }
mkdir -p "$dest"

if ! gh run download "$run_id" --pattern 'unagi-reader-release-*' --dir "$dest"; then
    echo "Run $run_id has no release artifact. A pull request run skips the release build unless the PR changes the build or packaging; run the workflow by hand and use --run, or build locally." >&2
    exit 1
fi
zip=$(find "$dest" -name UnagiReader-adhoc.zip 2>/dev/null | head -n 1 || true)
[ -n "$zip" ] || { echo "UnagiReader-adhoc.zip not found in the artifact." >&2; exit 1; }

# The artifact records the PR head it was built for. Refuse a build that is not the one asked for.
if [ -n "$expected_head" ]; then
    env_file=$(find "$dest" -name environment.txt 2>/dev/null | head -n 1 || true)
    built_head=$(sed -n 's/^pr_head=//p' "${env_file:-/dev/null}" | head -n 1)
    [ "$built_head" = "$expected_head" ] || { echo "Artifact was built for '${built_head:-unknown}', not $expected_head." >&2; exit 1; }
fi

app_dir=$dest/app
ditto -x -k "$zip" "$app_dir"
app=$app_dir/UnagiReader.app
codesign --verify --deep --strict "$app"

# Read the attributes as a plain assignment so a failing xattr stops the script (set -e does not
# apply inside an `if` condition, where a failed read would look like "no attribute").
attrs=$(xattr -lr "$app")
if grep -q com.apple.quarantine <<<"$attrs"; then
    echo "WARNING: $app still carries com.apple.quarantine. Check how it was extracted before opening it." >&2
    exit 1
fi

echo "Ready: $app (ad hoc signed, not notarized, no quarantine attribute)"
echo "Open a NEW synthetic instance, never the user's library:"
echo "  open -n '$app' --args --data-directory /private/tmp/unagi-reader-ci-data-$label --seed-demo"
echo "Then confirm the process arguments include that --data-directory (pgrep -fl UnagiReader) and the window shows synthetic subscriptions."
