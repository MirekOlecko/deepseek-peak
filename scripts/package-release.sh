#!/bin/bash
# Package a previously built universal app. Does not compile or install it.
set -euo pipefail
cd "$(dirname "$0")/.."
APP_DIR="build/DeepSeekPeak.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
codesign --verify --strict "$APP_DIR"
lipo "$APP_DIR/Contents/MacOS/DeepSeekPeak" -verify_arch arm64 x86_64
mkdir -p dist
NAME="DeepSeekPeak-${VERSION}-macOS-universal"
[[ ! -e "dist/$NAME.zip" && ! -e "dist/$NAME.dmg" ]] || { echo 'Release files already exist; do not overwrite a published version.' >&2; exit 2; }
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/deepseek-peak-release.XXXXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto --norsrc --noextattr --noacl "$APP_DIR" "$STAGE/DeepSeekPeak.app"
cp LICENSE "$STAGE/LICENSE.txt"
cat > "$STAGE/INSTALL.txt" <<'EOF'
DeepSeek Peak — macOS 13+ / Apple Silicon and Intel

Drag DeepSeekPeak.app to Applications, then open it.
There is no Dock icon: use the desktop widget or menu bar indicator.

This community release is ad-hoc signed, not notarized by Apple.
If macOS blocks it, verify you downloaded it from:
https://github.com/MirekOlecko/deepseek-peak/releases
Then follow System Settings > Privacy & Security > Open Anyway after trying
to launch the app. Do not disable Gatekeeper globally.
https://support.apple.com/en-us/102445

No API key or DeepSeek account is needed. The app uses a local editable schedule,
not live billing data. Check DeepSeek's official pricing before relying on it.

Source, license and help: https://github.com/MirekOlecko/deepseek-peak
EOF
ln -s /Applications "$STAGE/Applications"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGE/DeepSeekPeak.app" "dist/$NAME.zip"
hdiutil create -quiet -volname 'DeepSeek Peak' -srcfolder "$STAGE" -format UDZO "dist/$NAME.dmg"
cp "$STAGE/INSTALL.txt" dist/INSTALL.txt
(cd dist && shasum -a 256 "$NAME.zip" "$NAME.dmg" > SHA256SUMS.txt)
echo "Release assets created in dist/ ($VERSION)"
