import SwiftUI
import AppKit
import ApplicationServices

// Spotify prototype, first two gates:
//  1. Apple Events permission in a signed, sandboxed build (+ basic controls and latency)
//  2. Desktop-level window behavior (hover, Spaces, Mission Control, Stage Manager)
// Add to the CWTest APP target. In ContentView, show ProbeView3().

enum SpotifyGate {
    static let bundleID = "com.spotify.client"

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// Blocks while macOS shows its permission prompt, so call off the main thread.
    static func permissionStatus(ask: Bool) -> String {
        guard isRunning else { return "Spotify is not running (start it, then check again)" }
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        guard let desc = target.aeDesc else { return "Could not build target descriptor" }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, ask)
        switch status {
        case 0: return "Granted (0)"
        case -1743: return "Denied (-1743). Re-enable in System Settings > Privacy & Security > Automation"
        case -1744: return "Not asked yet (-1744)"
        case -600: return "Spotify not found (-600)"
        default: return "Other status: \(status)"
        }
    }

    /// Runs an AppleScript snippet against Spotify and reports result and elapsed time.
    static func run(_ command: String) -> String {
        let source = """
        tell application id "\(bundleID)"
            \(command)
        end tell
        """
        let start = Date()
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        if let error {
            let msg = error["NSAppleScriptErrorMessage"] ?? "unknown"
            let num = error["NSAppleScriptErrorNumber"] ?? "?"
            return "Script error \(num): \(msg) [\(ms) ms]"
        }
        return "\(result?.stringValue ?? "ok") [\(ms) ms]"
    }

    static let trackInfo = """
    return (player state as text) & " | " & (name of current track) & " | " & (artist of current track)
    """
}

// MARK: - Desktop-level window

struct DesktopCard: View {
    @State private var hovering = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(hovering ? Color.green.opacity(0.85) : Color.blue.opacity(0.75))
            VStack(spacing: 8) {
                Text(hovering ? "Hover works" : "Desktop-level test")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                if hovering {
                    HStack(spacing: 18) {
                        Image(systemName: "backward.fill")
                        Image(systemName: "pause.fill")
                        Image(systemName: "forward.fill")
                    }
                    .font(.system(size: 22))
                }
            }
            .foregroundStyle(.white)
        }
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: hovering)
    }
}

enum DesktopTestWindow {
    private static var window: NSWindow?

    static var isOpen: Bool { window != nil }

    static func toggle() {
        if let w = window {
            w.close()
            window = nil
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 220, height: 220),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        // Just above the desktop icons, well below normal app windows.
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.contentView = NSHostingView(rootView: DesktopCard())
        w.orderFrontRegardless()
        window = w
    }
}

// MARK: - Test screen

struct ProbeView3: View {
    @State private var log = "Start Spotify, play a track, then press Check permission."
    @State private var windowOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gate 1: Apple Events").font(.headline)
            HStack {
                Button("Check permission") { check() }
                Button("Now playing") { log = SpotifyGate.run(SpotifyGate.trackInfo) }
            }
            HStack {
                Button("Previous") { log = "previous: " + SpotifyGate.run("previous track") }
                Button("Play/Pause") { log = "playpause: " + SpotifyGate.run("playpause") }
                Button("Next") { log = "next: " + SpotifyGate.run("next track") }
                Button("Volume 30") { log = "volume 30: " + SpotifyGate.run("set sound volume to 30") }
                Button("Volume 70") { log = "volume 70: " + SpotifyGate.run("set sound volume to 70") }
            }

            Divider()

            Text("Gate 2: Desktop-level window").font(.headline)
            Button(windowOpen ? "Close desktop window" : "Open desktop window") {
                DesktopTestWindow.toggle()
                windowOpen = DesktopTestWindow.isOpen
            }

            Divider()
            Text(log)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(minWidth: 620, minHeight: 360)
    }

    private func check() {
        log = "Checking..."
        DispatchQueue.global().async {
            let result = SpotifyGate.permissionStatus(ask: false)
            DispatchQueue.main.async { log = "Permission: " + result }
        }
    }
}
