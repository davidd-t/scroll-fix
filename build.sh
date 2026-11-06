#!/bin/bash
# Builds ScrollFix.app into ./build
set -euo pipefail
cd "$(dirname "$0")"

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN_DIR=$(swift build -c release "${ARCHS[@]}" --show-bin-path)

APP=build/ScrollFix.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/ScrollFix" "$APP/Contents/MacOS/ScrollFix"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature (no developer account needed). By default an ad-hoc
# signature pins the exact binary hash, so macOS would drop Accessibility
# access on every rebuild. Requiring only the bundle identifier keeps the
# permission valid across rebuilds.
codesign --force --sign - \
    --requirements '=designated => identifier "io.github.davidd-t.ScrollFix"' \
    "$APP"

echo "Built $APP"
