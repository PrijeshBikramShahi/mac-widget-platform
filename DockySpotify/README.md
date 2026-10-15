# Widgion Spotify for Docky

A Spotify-only player built from the same `Widgion/SpotifyService.swift` used by the desktop mini-player. It never reads the system Now Playing source, so browser media cannot replace Spotify's title, artwork, or controls.

## Layouts

- 1 tile: artwork with play/pause on hover.
- 2 tiles: artwork and previous/play/next.
- 3–4 tiles: artwork, title, artist, and playback controls.
- Expanded: artwork, track/album details, seek slider, elapsed/remaining time, volume, and Open Spotify.
- Right-click: Open Spotify, playback, volume presets, and Refresh Spotify.
- Closed Spotify: Open Spotify placeholder. Polling does not launch Spotify.

Docky's widget settings provide an artwork background tint option. Older hosts that do not supply configuration use the default tint.

## Build and check

From the repository root:

```sh
bash DockySpotify/build.sh
bash DockySpotify/test.sh
```

Output: `build/DockySpotify/WidgionSpotify.dockywidget`.

The build script targets the current Mac's architecture and signs locally with an ad-hoc signature. For distribution, set `WIDGION_SIGN_IDENTITY` to a Developer ID Application identity and build for the intended architecture. Local bundle tests verify Objective-C protocol conformance and all layout constructors; installed-host compatibility must still be checked in Docky.

## Install

Copy the bundle into `~/Library/Application Support/Docky/Widgets/`, or use Docky Settings → Widget Store → Install from File. Restart Docky. In Widget Store, confirm **Widgion Spotify** is loaded. Open **Edit Dock**, find **Widgion Spotify**, and drag the desired width into the dock. Once it works, remove the built-in Now Playing widget.

Spotify automation permission belongs to the host app (Docky). If needed, allow Docky to control Spotify in System Settings → Privacy & Security → Automation. No Spotify web API account or API token is used.

## Implementation

`DockyWidgetPlugin.swift` declares Docky's Cocoa plugin ABI. `WidgionSpotifyWidget.swift` creates flexible hosting views sharing one service instance. The view uses actual bounds to handle Docky versions that retain a view across span changes.

Spotify reads and commands run on one serial background queue with bounded Apple Event timeouts. Playback state refreshes on Spotify notifications, wake, and a three-second fallback timer. Position interpolates locally between snapshots; seek and volume are committed when slider editing ends. New-track artwork clears immediately, and superseded downloads cannot overwrite the current track.

`Tests/ServiceChecks.swift` checks playback state, duration/position, paused timing, track changes, and number formatting. `Tests/BundleChecks.swift` loads the real bundle through a separately compiled host protocol. `Tests/RenderPreview.swift` renders each layout with synthetic data without connecting to Spotify.

Public contract: https://github.com/josejuanqm/docky/blob/main/Docky/Services/ExternalWidget.swift
