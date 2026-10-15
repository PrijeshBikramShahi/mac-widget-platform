#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output="${1:-$PWD/build/DockySpotify}"
bundle="$output/WidgionSpotify.dockywidget"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
xcrun swiftc -swift-version 5 -parse-as-library -emit-library \
  -Xlinker -bundle -module-name WidgionSpotify \
  -target "$(uname -m)-apple-macosx14.0" \
  -module-cache-path /tmp/widgion-swift-cache \
  Widgion/SpotifyService.swift DockySpotify/Sources/*.swift \
  -o "$bundle/Contents/MacOS/WidgionSpotify"
cp DockySpotify/Resources/Info.plist "$bundle/Contents/Info.plist"
cp DockySpotify/Resources/settings.json "$bundle/Contents/Resources/settings.json"
# Ad-hoc signing is for this machine. Set WIDGION_SIGN_IDENTITY to a Developer ID for distribution.
codesign --force --sign "${WIDGION_SIGN_IDENTITY:--}" "$bundle"
codesign --verify --strict "$bundle"
printf '%s\n' "$bundle"
