#!/bin/bash
set -e
cd "$(dirname "$0")"

pkill -f iGest 2>/dev/null || true
sleep 0.5

echo "Building..."
swift build 2>&1 | tail -3

echo "Packaging..."
rm -rf iGest.app
mkdir -p iGest.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/iGest iGest.app/Contents/MacOS/iGest
cp Info.plist iGest.app/Contents/Info.plist
codesign --force --sign - iGest.app

echo "Launching..."
open iGest.app

echo "✓ iGest running"
