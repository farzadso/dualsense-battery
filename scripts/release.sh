#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/test.sh"
"$ROOT/scripts/build.sh" --universal
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ARCHIVE="DualSense-Battery-$VERSION-macOS-universal.zip"
RELEASE_DIR="$ROOT/build/release"
mkdir -p "$RELEASE_DIR"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/build/DualSense Battery.app" "$RELEASE_DIR/$ARCHIVE"
(cd "$RELEASE_DIR" && shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt)
printf 'Release archive: %s/%s\n' "$RELEASE_DIR" "$ARCHIVE"
