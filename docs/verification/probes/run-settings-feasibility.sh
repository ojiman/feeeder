#!/bin/bash
# Local synthetic spike only; no product source is modified in the checkout.
set -euo pipefail
probe_assets=$(cd "$(dirname "$0")" && pwd)
probe_root=$(git -C "$probe_assets" rev-parse --show-toplevel)
probe_source=$(mktemp -d /private/tmp/feeeder-settings-probe.XXXXXX)
export FEEEDER_SETTINGS_PROBE_OUTPUT="$probe_source/output"
git -C "$probe_root" archive e9bcd933873fe920fc3751ba417afe561ff2a99c | tar -x -C "$probe_source"
git -C "$probe_source" apply "$probe_assets/settings-typography.patch"
git -C "$probe_source" apply "$probe_assets/settings-live-update.patch"
cp "$probe_assets/settings-feasibility.swift" "$probe_source/Tests/ReaderUITests/SettingsFeasibilityProbe.swift"
printf 'Synthetic source and output: %s\n' "$probe_source"
swift test --package-path "$probe_source" --scratch-path "$probe_source/.build" --force-resolved-versions --disable-keychain --disable-netrc --filter SettingsFeasibilityProbe 2>&1 | tee "$probe_source/result.log"
