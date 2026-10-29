#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DualSense Battery.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Source" "$ROOT/build/ModuleCache"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Sources/"*.swift "$APP/Contents/Resources/Source/"
xcrun swiftc -swift-version 5 -O \
  -target "$(uname -m)-apple-macosx13.0" \
  -module-cache-path "$ROOT/build/ModuleCache" \
  -framework AppKit -framework GameController \
  "$ROOT/Sources/Selection.swift" "$ROOT/Sources/main.swift" \
  -o "$APP/Contents/MacOS/DualSenseBattery"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"
