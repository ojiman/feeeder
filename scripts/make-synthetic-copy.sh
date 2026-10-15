#!/usr/bin/env bash
# Copies an existing app for synthetic checks. Never opens it or changes the source.
# Usage: make-synthetic-copy.sh [APP [NEW_DATA_DIRECTORY]]
# With no arguments, takes .build/Unagi Reader.app from this repository.
# Needs macOS tools and Python 3 (also used by the documents check).
set -euo pipefail

usage() { echo "Usage: make-synthetic-copy.sh [APP [NEW_DATA_DIRECTORY]]" >&2; exit 2; }
[ "$#" -le 2 ] || usage
case "${1-default}" in ''|-*) usage ;; esac
[ "${2-default}" != '' ] || usage
for tool in python3 ditto plutil codesign; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done

source_app=${1:-"$(cd "$(dirname "$0")/.." && pwd)/.build/Unagi Reader.app"}
plist=$source_app/Contents/Info.plist
if [ ! -f "$plist" ] || [ -L "$plist" ] || [ -L "$source_app/Contents" ]; then
    echo "Expected an app with its own Contents/Info.plist: $source_app. Build it first with bash scripts/build-app.sh release." >&2
    exit 1
fi
executable=$(plutil -extract CFBundleExecutable raw -o - "$plist")
case "$executable" in ''|*/*) echo "Invalid app executable: $executable" >&2; exit 1 ;; esac
[ -x "$source_app/Contents/MacOS/$executable" ] || { echo "App executable is missing: $source_app" >&2; exit 1; }

data_directory=''
if [ "$#" -eq 2 ]; then
    data_directory=$(python3 - "$2" "$source_app" <<'PY'
import os
import sys

target = os.path.realpath(sys.argv[1])
library = os.path.realpath(os.path.expanduser("~/Library/Application Support/UnagiReader"))
source = os.path.realpath(sys.argv[2])
# Treat case variants as the same path, as on the usual macOS volume.
if target.casefold() == library.casefold() or target.casefold().startswith(library.casefold() + os.sep):
    sys.exit("Refusing the real library or a path inside it.")
if target.casefold() == source.casefold() or target.casefold().startswith(source.casefold() + os.sep):
    sys.exit("The data directory must be outside the source app.")
if os.path.lexists(sys.argv[1]):
    sys.exit("The data directory already exists; use a new directory for synthetic data.")
print(target)
PY
    )
fi

work=$(mktemp -d "${TMPDIR:-/private/tmp}/unagi-reader-synthetic.XXXXXX")
work=$(cd "$work" && pwd -P)
trap 'rm -rf "$work"' EXIT
app=$work/Unagi\ Reader.app
ditto "$source_app" "$app"
plutil -replace CFBundleIdentifier -string xyz.ojima.UnagiReader.Synthetic "$app/Contents/Info.plist"
# Changing the identifier invalidates the copied signature; this copy is ad hoc only.
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
data_directory=${data_directory:-$work/data}
mkdir "$data_directory"
trap - EXIT

echo "Ready: $app (synthetic bundle identifier, ad hoc signed)"
echo "Open a NEW instance with its own data directory:"
printf '  open -n %q --args --data-directory %q --seed-demo\n' "$app" "$data_directory"
echo "Before interacting, confirm the --data-directory with pgrep -fl UnagiReader and the synthetic subscriptions in the window."
