#!/bin/bash
# Builds a universal DeepSeekPeak.app (Apple Silicon + Intel) into build/.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
[[ "$CONFIG" == release || "$CONFIG" == debug ]] || { echo 'Use release or debug' >&2; exit 2; }
# Every application build consumes a new number, even if compilation fails.
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)
[[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] || exit 2
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((CURRENT_BUILD + 1))" Resources/Info.plist
echo "==> Universal build $((CURRENT_BUILD + 1)) ($CONFIG)"
swift build -c "$CONFIG" --arch arm64 --arch x86_64 \
    -Xswiftc -debug-prefix-map -Xswiftc "$PWD=."

BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)"
APP_DIR="build/DeepSeekPeak.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/DeepSeekPeak" "$APP_DIR/Contents/MacOS/DeepSeekPeak"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# Remove local/debug symbol paths from distributed release binaries.
if [[ "$CONFIG" == release ]]; then
    xcrun strip -S -x "$APP_DIR/Contents/MacOS/DeepSeekPeak"
fi

# Ad-hoc signing is integrity protection, not Developer ID signing/notarization.
# Downloaded releases may need approval in System Settings > Privacy & Security.
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
lipo "$APP_DIR/Contents/MacOS/DeepSeekPeak" -verify_arch arm64 x86_64

echo "==> done: $APP_DIR"
echo "    run:  open \"$APP_DIR\""
