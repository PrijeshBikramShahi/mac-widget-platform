<div align="center">

# widgion.

**Your desktop, your widgets.**

A customizable, native macOS widget collection with a Spotify mini-player, Nepali and English calendar, clock, weather, and battery status.

Built with **SwiftUI · AppKit · WidgetKit**.

</div>

---

## Preview

> Add a screenshot of your running desktop to `assets/screenshots/desktop.png` to display it here.

<!-- Uncomment once the screenshot exists:
![Widgion desktop widgets](assets/screenshots/desktop.png)
-->

Widgion places independent, movable widgets directly on your desktop. Choose what to show, set their appearance, and position each component to fit your wallpaper and workflow.

## Features

| Widget | What it does |
| --- | --- |
| **Clock** | Digital clock with configurable display style, 12/24-hour formatting, and accent color. |
| **Calendar** | English (AD), Nepali (BS), or combined date display. Combined/Nepali dates use Nepal time. |
| **Weather** | Current conditions for a chosen city, with Celsius/Fahrenheit selection and cached data. Powered by Open-Meteo. |
| **Battery** | Battery status with customizable style, accent color, and charging indicator. |
| **Spotify mini-player** | Album artwork, playback controls, volume, and an expandable interface dedicated to Spotify. |

### Make it yours

- **Independent desktop panels:** move and enable widgets individually.
- **Snap-to-grid editing:** drag to align with 16-point gaps, or hold **Option** while dragging for free placement.
- **Glass appearance:** choose a window material and adjust transparent-background opacity.
- **Widget-specific settings:** customize size, style, content, and accent colors, including custom hex colors.
- **Menu bar controls:** edit layout, show/hide widgets or player, open settings, and quit.
- **Launch at login:** enable from Widgion settings.

### Spotify, without unrelated media

The player communicates with the **Spotify desktop app** rather than taking the system-wide Now Playing source. Media playing in a browser won't replace your Spotify track information. Hover for controls, double-click artwork to open Spotify, or right-click for player actions.

A separate **Docky Spotify** plugin is included for users who want the same Spotify-focused experience inside [Docky](https://github.com/josejuanqm/docky).

## Getting started

### Requirements

- macOS and Xcode with the macOS SDK
- Swift 5 and Xcode command line tools
- Spotify for the mini-player (optional)
- Internet access for live weather updates
- Docky only if you want to use the optional Docky plugin

> **Deployment target:** The checked-in Xcode project currently specifies `MACOSX_DEPLOYMENT_TARGET = 26.5`. Check your installed SDK and adjust the project target if you intend to build on a different macOS version. The separate Docky plugin build script targets macOS 14.0.

### Build the macOS app

```bash
# From the repository root
open Widgion.xcodeproj
```

In Xcode, select the **Widgion** application scheme, choose **My Mac**, then **Product → Run** (`⌘R`). You can also use **Product → Archive** to prepare a build for installation.

To install a locally built `.app`, copy the resulting **Widgion.app** to `/Applications` and open it there. If you distribute the app to others, signing and notarization may be necessary.

### First launch

1. Find the **Widgion** icon in the macOS menu bar.
2. Select **Settings…** and toggle the widgets you want.
3. Enable **Edit layout** to drag them into position.
4. Hold **Option** while dragging to bypass alignment snapping.
5. Disable **Edit layout** to lock the arrangement.
6. Optionally turn on **Launch at login**.

macOS may request permission to let Widgion control Spotify. Allow it under **System Settings → Privacy & Security → Automation** for Spotify controls to work.

## Optional: Docky Spotify widget

The repository also contains a standalone Docky widget bundle.

```bash
# Run from the repository root
bash DockySpotify/build.sh
bash DockySpotify/test.sh
```

The build produces:

```text
build/DockySpotify/WidgionSpotify.dockywidget
```

Copy the bundle into `~/Library/Application Support/Docky/Widgets/`, or install it through **Docky Settings → Widget Store → Install from File**. Restart Docky, find **Widgion Spotify**, and add it in **Edit Dock**.

The plugin supports compact artwork layouts, wider playback layouts, and an expanded view with track details, seeking, and volume. Docky requires its own permission to automate Spotify.

For plugin-specific implementation and compatibility details, see [`DockySpotify/README.md`](DockySpotify/README.md).

## Project structure

```text
.
├── Widgion/                 # Menu bar app, settings, Spotify, desktop panels
│   └── Desktop/             # Desktop widget views, layout, weather service
├── WidgionWidgets/          # WidgetKit clock, calendar, weather, battery
├── Shared/                  # Shared AD/BS calendar and date functionality
├── DockySpotify/            # Optional Spotify plugin for Docky
├── Tests/                   # Calendar and behavior checks
├── Widgion.xcodeproj/       # Xcode project
└── RESOURCE_AUDIT.md        # Performance/efficiency review
```

## Development and testing

Run the project checks:

```bash
bash Tests/run.sh
```

For the Docky plugin:

```bash
bash DockySpotify/test.sh
```

The application uses native Apple frameworks and does not require a third-party Swift package dependency according to the repository audit. Spotify playback is driven by local AppleScript automation; the Docky integration does **not** require Spotify Web API credentials. Weather requests use Open-Meteo.

For known efficiency opportunities and measurements, see [`RESOURCE_AUDIT.md`](RESOURCE_AUDIT.md). The audit identifies potential improvements; do not treat those recommendations as already implemented.

## Screenshots

To show the app in action, capture screenshots of your actual setup and add them to the repository, for example:

```text
assets/screenshots/
├── desktop.png
├── widgets.png
├── spotify-player.png
└── settings.png
```

Then uncomment the preview image near the top of this README. Additional images can be added using ordinary Markdown, e.g.:

```markdown
![Spotify mini-player](assets/screenshots/spotify-player.png)
![Widgion settings](assets/screenshots/settings.png)
```

For a clearer GitHub preview, use a high-resolution full-desktop screenshot and crop separate images for the small widgets. Avoid shrinking several tiny widgets into a single narrow comparison image.

## Current scope

Widgion includes both independently positioned desktop panels and WidgetKit widget definitions. The Spotify player depends on the desktop Spotify application, while weather requires network access for fresh conditions. Build and host compatibility should be tested on the macOS version where you intend to run the application.

---

<div align="center">

**widgion.** — a more personal macOS desktop.

</div>
