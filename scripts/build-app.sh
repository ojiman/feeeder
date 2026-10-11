#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration=${1:-debug}
case "$configuration" in debug|release) ;; *) echo "Usage: build-app.sh [debug|release]" >&2; exit 2 ;; esac
if [ "$configuration" = release ]; then build_dir=/private/tmp/feeeder-v1-release; else build_dir=/private/tmp/rss-reader-build; fi
swift build -c "$configuration" --scratch-path "$build_dir"
binary_dir=$(swift build -c "$configuration" --scratch-path "$build_dir" --show-bin-path)
app_dir="$PWD/.build/UnagiReader.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp ThirdPartyNotices.md "$app_dir/Contents/Resources/ThirdPartyNotices.md"
# Replace the inode: overwriting an executable previously launched on macOS
# can retain stale kernel code-signature cache entries and terminate it with SIGKILL.
task_binary=$(mktemp "$app_dir/Contents/MacOS/RSSReader.XXXXXX")
cp "$binary_dir/RSSReader" "$task_binary"
chmod 755 "$task_binary"
mv -f "$task_binary" "$app_dir/Contents/MacOS/RSSReader"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>RSSReader</string>
<key>CFBundleIdentifier</key><string>jp.ojiman.UnagiReader.Development</string>
<key>CFBundleName</key><string>Unagi Reader</string>
<key>CFBundleDisplayName</key><string>Unagi Reader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
printf 'Built: %s\n' "$app_dir"
