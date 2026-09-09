#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=/private/tmp/rss-reader-build
swift build --scratch-path "$build_dir"
binary_dir=$(swift build --scratch-path "$build_dir" --show-bin-path)
app_dir="$PWD/.build/RSS Reader.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$binary_dir/RSSReader" "$app_dir/Contents/MacOS/RSSReader"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>RSSReader</string>
<key>CFBundleIdentifier</key><string>jp.ojiman.RSSReader.Development</string>
<key>CFBundleName</key><string>RSS Reader</string>
<key>CFBundleDisplayName</key><string>RSS Reader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>LSMinimumSystemVersion</key><string>26.6</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
printf 'Built: %s\n' "$app_dir"
