#!/bin/bash
# Builds the app, installs it into /Applications and launches it.
# Usage: ./scripts/install-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh "${1:-release}"

echo "==> stopping the running copy"
pkill -f 'DeepSeekPeak.app/Contents/MacOS/DeepSeekPeak' || true
sleep 1

echo "==> installing into /Applications"
rm -rf /Applications/DeepSeekPeak.app
cp -R build/DeepSeekPeak.app /Applications/DeepSeekPeak.app
codesign --verify --strict /Applications/DeepSeekPeak.app

open /Applications/DeepSeekPeak.app
echo "==> done: /Applications/DeepSeekPeak.app"
