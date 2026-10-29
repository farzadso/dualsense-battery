#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/ModuleCache"
xcrun swiftc -swift-version 5 \
  -module-cache-path "$ROOT/build/ModuleCache" \
  "$ROOT/Sources/Selection.swift" "$ROOT/Tests/main.swift" \
  -o "$ROOT/build/selection-tests"
"$ROOT/build/selection-tests"
