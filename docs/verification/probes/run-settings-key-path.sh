#!/bin/bash
# Temporary synthetic source only. Prepares an unsigned local app; does not launch it.
set -euo pipefail
probe_assets=$(cd "$(dirname "$0")" && pwd)
probe_repo=$(git -C "$probe_assets" rev-parse --show-toplevel)
probe_source=$(mktemp -d /private/tmp/feeeder-settings-keys.XXXXXX)
git -C "$probe_repo" archive e9bcd933873fe920fc3751ba417afe561ff2a99c | tar -x -C "$probe_source"
for patch in settings-typography settings-live-update settings-key-path; do
  git -C "$probe_source" apply "$probe_assets/$patch.patch"
done
cp "$probe_assets/settings-key-bridge.swift" "$probe_source/Sources/RSSReader/SettingsKeyProbe.swift"
cp "$probe_assets/settings-key-path.swift" "$probe_source/Tests/ReaderUITests/SettingsKeyPathProbe.swift"
cp "$probe_assets/settings-feasibility.swift" "$probe_source/Tests/ReaderUITests/SettingsFeasibilityProbe.swift"
export FEEEDER_SETTINGS_PROBE_OUTPUT="$probe_source/output"
export FEEEDER_SETTINGS_PROBE_SUITE="Feeeder.SettingsProbe.$(basename "$probe_source")"
printf 'Synthetic source: %s\n' "$probe_source"
swift test --configuration release --package-path "$probe_source" --scratch-path "$probe_source/.build" --force-resolved-versions --disable-keychain --disable-netrc --filter 'SettingsKeyPathProbe|NativeArticleTextTests|SettingsFeasibilityProbe' 2>&1 | tee "$probe_source/result.log"
mkdir -p "$probe_source/Feeeder Settings Probe.app/Contents/MacOS" "$probe_source/web"
cp "$probe_source/.build/release/RSSReader" "$probe_source/Feeeder Settings Probe.app/Contents/MacOS/RSSReader"
cp "$probe_assets/settings-key-original.html" "$probe_source/web/original.html"
python3 - "$probe_source" <<'PYAPP'
from pathlib import Path
import plistlib,sys
root=Path(sys.argv[1])
info=dict(CFBundleIdentifier='jp.ojiman.Feeeder.SettingsProbe.'+root.name,CFBundleExecutable='RSSReader',CFBundleName='Feeeder Settings Probe',CFBundlePackageType='APPL',LSMinimumSystemVersion='27.0',NSHighResolutionCapable=True)
(root/'Feeeder Settings Probe.app/Contents/Info.plist').write_bytes(plistlib.dumps(info))
PYAPP
printf 'UI preparation only; see docs/verification/2026-10-10-settings-key-path.md for synthetic launch and checks.\n'
