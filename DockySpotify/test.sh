#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/widgion-spotify-tests.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path /tmp/widgion-swift-cache \
  Widgion/SpotifyService.swift DockySpotify/Sources/DockySpotifyView.swift \
  DockySpotify/Tests/ServiceChecks.swift -o "$build_dir/service-checks"
"$build_dir/service-checks"
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path /tmp/widgion-swift-cache \
  DockySpotify/Sources/DockyWidgetPlugin.swift DockySpotify/Tests/BundleChecks.swift \
  -o "$build_dir/bundle-checks"
"$build_dir/bundle-checks" "$PWD/build/DockySpotify/WidgionSpotify.dockywidget"
