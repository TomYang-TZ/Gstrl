#!/bin/bash
set -e
cd "$(dirname "$0")"

pkill -f iGest 2>/dev/null || true
sleep 0.5

echo "Building..."
xcodebuild -project iGest.xcodeproj -scheme iGest -configuration Release build 2>&1 | tail -3

rm -rf iGest.app
cp -R ~/Library/Developer/Xcode/DerivedData/iGest-*/Build/Products/Release/iGest.app ./iGest.app
codesign --force --sign - iGest.app

# Reset accessibility permission so the app gets a fresh prompt on launch
tccutil reset Accessibility com.tomyang.iGest 2>/dev/null || true

# Open System Settings to Accessibility pane (user must toggle iGest on)
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

sleep 1
open iGest.app

echo "✓ iGest launched. Toggle it ON in the Accessibility pane that just opened."
