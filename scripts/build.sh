#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DualSense Battery.app"
case "${1:-}" in
  "") ARCHS=("$(uname -m)") ;;
  --universal) ARCHS=(arm64 x86_64) ;;
  *) echo "Usage: $0 [--universal]" >&2; exit 2 ;;
esac
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Source" "$ROOT/build/ModuleCache"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/Sources/"*.swift "$APP/Contents/Resources/Source/"
BINARIES=()
for ARCH in "${ARCHS[@]}"; do
  BINARY="$ROOT/build/DualSenseBattery-$ARCH"
  xcrun swiftc -swift-version 5 -O \
    -target "$ARCH-apple-macosx13.0" \
    -module-cache-path "$ROOT/build/ModuleCache" \
    -framework AppKit -framework GameController \
    "$ROOT/Sources/Selection.swift" "$ROOT/Sources/main.swift" \
    -o "$BINARY"
  BINARIES+=("$BINARY")
done
if [ "${#BINARIES[@]}" -gt 1 ]; then
  xcrun lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/DualSenseBattery"
else
  cp "${BINARIES[0]}" "$APP/Contents/MacOS/DualSenseBattery"
fi
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"
