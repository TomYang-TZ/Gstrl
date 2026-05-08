#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "Building..."
swift build 2>&1 | tail -3

echo "Packaging..."
rm -rf iGest.app
mkdir -p iGest.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/iGest iGest.app/Contents/MacOS/iGest
cp Info.plist iGest.app/Contents/Info.plist
codesign --force --sign - iGest.app

echo "✓ iGest.app ready"
