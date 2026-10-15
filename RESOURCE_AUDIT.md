# Widgion resource and efficiency audit

Reviewed 15 October 2026. Scope: the current working tree, including the desktop application, WidgetKit extension, Docky plugin, build configuration, and existing tests. Application source was not changed during this audit.

The largest opportunities are controlling when services run, limiting queued work, and avoiding publication of unchanged state. The project is small, uses native frameworks, and has no package dependencies. A broad rewrite is unnecessary.

**Architecture and existing strengths**

| Component | Current design | Assessment |
| --- | --- | --- |
| Desktop application | Menu bar app; four independent widget panels and a player panel | Keep the independently movable panels. Add explicit service lifecycle management. |
| Spotify | Shared source between app and Docky; serial AppleScript queue; notifications plus polling | Keep background execution, snapshot coalescing, generation checks, and local position interpolation. Shared source does not share a service across processes. |
| Weather | Async HTTP, persistent snapshot, stale indication, city/request identity checks | Preserve stale-data honesty and protection against obsolete responses. Separate retry scheduling from display freshness. |
| WidgetKit | Separate providers for clock, calendar, weather, battery | Keep OS-managed scheduling; consolidate duplicated models and configuration. |
| Docky | One lazy service per plugin instance, reused across that instance's views | Keep lazy discovery. Track active consumers so previews and retained views do not keep unnecessary polling alive. |
| Layout/settings | Small geometry calculations, weak panel registry, AppStorage | Lower priority than service work. Existing resize guards already avoid redundant window resizing. |

**Prioritized findings**

| Priority | Finding | Recommended change | Likely benefit / effort |
| --- | --- | --- | --- |
| 1 | Spotify polls every three seconds without visibility gating | Consumer-aware lifecycle and adaptive fallback polling | High idle-work reduction / medium |
| 1 | Spotify command queue can accumulate obsolete volume writes | Keep only the latest pending volume; bound queued work | High responsiveness benefit under latency / medium |
| 1 | Weather staleness also controls request eligibility | Independent retry deadline, backoff, location cache, task cancellation | High network reduction during failures or stale upstream data / medium |
| 2 | Identical snapshots publish changes repeatedly | Compare values; separate metadata from progress; avoid redundant resets | Lower UI invalidation overhead / small–medium |
| 2 | Battery singleton polls for the process lifetime | Power-source notifications with explicit start/stop | Removes periodic battery polling / small |
| 2 | Docky build does not request compiler optimization | Explicit Debug and Release modes; Release uses `-O` | Low-effort production improvement; measure actual gain / small |
| 3 | Calendar and paused progress update unnecessarily | Calendar day-boundary scheduling; pause progress updates | Fewer scheduled UI updates / small |
| 3 | Weather/configuration logic is duplicated across targets | Shared Swift sources and app/extension shared storage | Consistency and conditional network savings / medium |
| 3 | Artwork processing and glass may contribute rendering cost | Measure first; downsample and cache where justified | Potential memory/GPU reduction / medium |
| 4 | Broad settings notifications and formatter construction | Filter relevant changes; reuse formatting logic | Small cleanup / small |

**1. Make services follow their consumers**

[SpotifyService.swift:34](/Users/prizesh/code/CWTEST/CWTest/Widgion/SpotifyService.swift:34) installs playback/workspace notifications and a permanent three-second task. [MiniPlayer.swift:224](/Users/prizesh/code/CWTEST/CWTest/Widgion/MiniPlayer.swift:224) retains the service statically; startup constructs it even when `player.enabled` is false. Hiding the panel calls `orderOut`, which does not stop the service.

This schedules nominally 1,200 sync attempts per hour per observing service. When Spotify is absent these attempts check running applications and reset state; they do not send snapshot Apple Events. When Spotify is running, successful cycles read the full snapshot, including while paused. Notifications and user actions can add more reads. These are code-derived rates, not measured CPU wakeups.

Introduce explicit consumer registration and cancellation. Track whether any consumer needs metadata or visible progress. Stop fallback polling when no consumer is visible or enabled, and retain lightweight application launch/termination observation as needed. Refresh immediately on activation. Do not use application foreground status as the sole visibility signal: desktop widgets intentionally remain useful while the app is inactive.

Use playback notifications as the primary trigger, retaining a fallback because delivery and external seek/volume changes need validation. Start with 15–30 seconds while visible and playing, a slower paused fallback, and none when Spotify is absent. At 30 seconds, scheduled fallback attempts fall from 1,200 to 120 per hour; this is a 90% reduction in that schedule, not a promise of 90% lower CPU usage. Expanded elapsed time can keep interpolating locally.

Docky needs consumer counting: disappearance of one preview must not stop a still-visible tile. Its current `.onAppear` starts observation without a matching release path. Native window visibility should supplement SwiftUI appearance callbacks where hosts retain views. The weather singleton also keeps its wake observer after the weather panel has been disabled.

Apple recommends responding to events and proactively stopping unnecessary activity rather than depending on App Nap: [timer guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html), [App Nap guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html).

**2. Bound Spotify commands and reduce publications**

[SpotifyService.swift:183](/Users/prizesh/code/CWTEST/CWTest/Widgion/SpotifyService.swift:183) permits approximately 6.7 volume sends per second. Every send enqueues an AppleScript operation on a serial queue; each operation can wait on a three-second Apple Event timeout. Throttling the submission rate does not bound the queue when Spotify responds slowly. Generation checks suppress obsolete snapshot results but do not discard queued commands. `setVolume` followed by `commitVolume` can also send the same volume twice, including menu presets and Docky's committed slider changes.

Keep one volume command in flight and one replaceable pending value. Deduplicate identical commits, preserve discrete transport actions, and fetch one snapshot after the command burst settles. Make stopped/hidden lifecycle generations invalidate pending work. Back off repeated automation errors instead of retrying every three seconds indefinitely. Consider caching the fixed snapshot script on its serial queue only after measuring compilation overhead.

A probe compiled against the production service confirmed **eight `objectWillChange` emissions for an identical paused snapshot**, and nine for repeated `apply(["notRunning"])`. The poll path's direct `reset` also writes unchanged properties. SwiftUI can coalesce emissions; these counts are not eight or nine proven renders.

Compare values before publishing. Keep position/time-anchor corrections distinct from track metadata so compact views do not invalidate solely because progress changed. A single metadata snapshot is useful only if unchanged fields are actually deduplicated. [PlayerVolumeSlider.swift:23](/Users/prizesh/code/CWTEST/CWTest/Widgion/PlayerVolumeSlider.swift:23) should likewise avoid unconditional value assignment and redraw requests when nothing changed.

**3. Give weather a real request policy**

[WeatherService.swift:73](/Users/prizesh/code/CWTEST/CWTest/Widgion/Desktop/WeatherService.swift:73) treats stale observation data as a reason to fetch again, even immediately after a successful request. The view calls refresh every minute. A probe using the existing stubbed HTTP infrastructure confirmed that two immediate refreshes after successfully receiving old upstream data issue **four additional HTTP requests**: geocoding and forecast each time.

With fast responses that remain old, the desktop loop can make approximately 120 HTTP requests per hour. Offline and invalid-city paths also lack increasing retry delays. Superseded forced requests are ignored on completion but are not explicitly cancelled by the service. Every network refresh geocodes the same city again.

Separate `observedAt` (whether the displayed weather is current), `fetchedAt` (when a response arrived), and `nextAttemptAt` (when another request is allowed). Keep the “Old data” label even after a successful stale response, but enforce a minimum retry interval. Cache city coordinates, reuse a fresh in-memory snapshot, and use bounded failure backoff such as 1, 2, 5, then 15 minutes. Manual refresh can bypass the deadline while still preventing overlapping requests. Own and cancel the active task when the city changes or a request is replaced.

Replace the every-minute cache check with scheduling at the next request deadline; schedule the visual stale transition separately. The WidgetKit repository has the same freshness/retry coupling and lacks in-flight deduplication. Its stale path requests another timeline after one minute, but WidgetKit decides when it actually runs. The file's “at most one call per 30 minutes” comment is therefore not enforced by its implementation.

**4. Match update cadence to visible information**

[DesktopBatteryView.swift:28](/Users/prizesh/code/CWTEST/CWTest/Widgion/Desktop/DesktopBatteryView.swift:28) starts a 30-second timer without tolerance or an invalidation path. Once initialized, the singleton continues polling after its widget closes. Use [IOPSNotificationCreateRunLoopSource](https://developer.apple.com/documentation/iokit/1523868-iopsnotificationcreaterunloopsou?language=occ), read once on activation, and remove the run-loop source when no longer needed. Publish only changed percentage/charging values.

The desktop calendar uses `.everyMinute`, although its content changes daily. Schedule the next local midnight using Calendar, and reschedule on wake and clock/time-zone changes; a fixed 24-hour interval would mishandle daylight-saving transitions. Keep the desktop clock's minute cadence because it displays minutes. Pause Docky's one-second progress timeline when paused or not visible.

WidgetKit's calendar already uses midnight entries. Its clock creates 60 minute entries; this is not 60 provider launches per hour. Apple's guidance recommends entries about five minutes apart and treats reload times as budgeted requests. Validate the desired clock precision on macOS rather than assuming minute entries are exact or moving live timers into the extension. See [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

**5. Consolidate selectively and profile graphics**

Desktop preferences do not configure WidgetKit: [WidgionConfig.swift:8](/Users/prizesh/code/CWTEST/CWTest/WidgionWidgets/Shared/WidgionConfig.swift:8) hardcodes location, clock format, and battery style. Weather models, mappings, caching, and battery reads are duplicated. Extract small shared Swift sources first. If both surfaces are supported, use an App Group for app/extension preferences and weather snapshots, with a cache key containing location and request parameters. Keep an extension fallback when the app is not running; shared storage alone does not coordinate concurrent network requests. Docky runs in a separate host and should not be assumed to share that App Group.

Artwork is retained at downloaded resolution, and each Docky view derives its own tint. There is no demonstrated artwork leak. If profiling shows image cost, downsample to the largest actual display pixel size, derive tint once per artwork, and use a bounded cache. Keep expensive image processing away from UI work, publishing the result on the main actor.

The wide player uses a live blur; optional glass panels and broad shadows may add compositor work. Compare transparent, glass, and wide-player modes while also measuring WindowServer. The default transparent style is already a sensible baseline. Do not remove independent panels or add offscreen rendering indiscriminately without evidence.

Every UserDefaults notification currently causes both window managers to reread settings, including unrelated cache/frame writes. Compare a small relevant settings snapshot before reconciliation. Reuse clock formatting machinery; this is lower priority at one update per minute. The old `ContentView` appears unused and can be removed as maintenance cleanup.

**Build and validation results**

- `bash Tests/run.sh`: passed layout, snapping, weather cache/wake/staleness checks.
- `bash DockySpotify/build.sh && bash DockySpotify/test.sh`: passed service checks, bundle loading, protocol conformance, metadata, and view construction.
- Unsigned Xcode Release build: passed for app and extension. Log: [build log](/tmp/widgion-efficiency-audit-build.log).
- Additional temporary probes confirmed the publication and weather-request counts above. No live Spotify commands were used by these probes.
- Source warnings: captured `self` in the battery timer becomes an error in Swift 6 language mode; extension build number `3` differs from app build number `2`. Simulator service diagnostics also appeared in this sandboxed macOS build, which still succeeded.
- [DockySpotify/build.sh:7](/Users/prizesh/code/CWTEST/CWTest/DockySpotify/build.sh:7) supplies no optimization flag. Add explicit Release `-O` and evaluate whole-module optimization. Keep assert-based check executables unoptimized, or replace assertions with checks that remain active in optimized tests.
- App/extension deployment targets are macOS 26.5, while Docky targets 14.0. Confirm this is intentional before broadening compatibility.

A process snapshot reported Widgion at 0.0% CPU / approximately 14.5 MiB RSS, its widget extension at 0.0% / 9.8 MiB, and Docky at 1.0% / 68.8 MiB. These are single observations of installed processes, not a controlled benchmark of this source. RSS is not total memory footprint, and Docky's totals cannot be attributed to this plugin. There is no evidence here for a claimed memory leak or a numerical battery-life improvement.

**Implementation order and acceptance checks**

1. Add injectable clock/Spotify transport seams and counters for snapshot requests, commands, HTTP requests, and state publications. Establish Release baselines with fixed scenarios.
2. Implement consumer lifecycle, bounded/latest-volume delivery, unchanged-state suppression, and explicit Docky Release optimization.
3. Implement weather deadlines, coordinate caching, cancellation, and backoff; replace battery polling and unnecessary calendar/progress schedules.
4. Consolidate app/extension data. Optimize image and glass rendering only if profiling shows a material cost.

Measure five-minute windows with Spotify closed, paused, playing, all widgets hidden, Docky expanded, and weather offline/stale. Repeat with transparent and glass materials. Use Instruments for CPU, allocations/physical footprint, SwiftUI updates, and energy; include host/WindowServer effects where relevant. Check volume interaction while the injected Spotify transport is slow, plus wake, time-zone changes, and repeated show/hide cycles.

Acceptance criteria: no recurring Spotify snapshot work without an active consumer; at most one in-flight and one pending volume write; identical paused metadata emits no unnecessary changes; stale upstream responses respect the request deadline; unchanged cities are not repeatedly geocoded; disabled battery widgets have no active timer/source; paused progress has no periodic UI work; all existing behavior checks still pass. These criteria provide concrete evidence before claiming CPU, memory, or battery improvements.
