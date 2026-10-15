#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d /tmp/widgion-checks.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path /tmp/widgion-swift-cache \
    Shared/CalendarDate.swift Shared/BikramSambatData.swift Tests/CalendarChecks.swift -o "$build_dir/calendar-checks"
"$build_dir/calendar-checks"
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path /tmp/widgion-swift-cache \
    Shared/CalendarDate.swift Shared/BikramSambatData.swift Widgion/Prefs.swift Widgion/Desktop/LayoutController.swift \
    Widgion/Desktop/WeatherService.swift Tests/BehaviorChecks.swift -o "$build_dir/checks"
"$build_dir/checks"
