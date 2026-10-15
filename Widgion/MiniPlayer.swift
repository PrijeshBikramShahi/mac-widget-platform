import SwiftUI
import AppKit
import Combine

// Spotify mini-player: album art, hover to reveal previous / play-pause / next + volume.
// Lives in a desktop-level panel (above wallpaper, below app windows).
// Add to the Widgion APP target. Needs the entitlements already set up:
//  - Apple Events exception for com.spotify.client
//  - com.apple.security.network.client

// MARK: - Spotify service

final class SpotifyService: ObservableObject {
    enum Status { case notRunning, stopped, playing, paused }

    @Published var status: Status = .notRunning
    @Published var title = ""
    @Published var artist = ""
    @Published var artwork: NSImage?
    @Published var volume: Double = 50

    var isActive: Bool { status == .playing || status == .paused }

    private let bundleID = "com.spotify.client"
    private var currentTrackID = ""
    private var lastVolumeSend = Date.distantPast
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init() {
        let dnc = DistributedNotificationCenter.default()
        observers.append((dnc, dnc.addObserver(
            forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil, queue: .main) { [weak self] n in
                self?.handle(n.userInfo ?? [:])
        }))

        let ws = NSWorkspace.shared.notificationCenter
        observers.append((ws, ws.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] n in
                guard let self, self.isSpotify(n) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.sync() }
        }))
        observers.append((ws, ws.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
                guard let self, self.isSpotify(n) else { return }
                self.reset(.notRunning)
        }))

        sync()
    }

    private func isSpotify(_ n: Notification) -> Bool {
        let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return app?.bundleIdentifier == bundleID
    }

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    // MARK: State updates

    /// Uses the notification's own details; only asks Spotify for the artwork URL, and only on a new track.
    private func handle(_ info: [AnyHashable: Any]) {
        switch info["Player State"] as? String ?? "" {
        case "Playing": status = .playing
        case "Paused": status = .paused
        default:
            reset(isRunning ? .stopped : .notRunning)
            return
        }
        title = info["Name"] as? String ?? title
        artist = info["Artist"] as? String ?? artist
        let id = info["Track ID"] as? String ?? ""
        if id != currentTrackID {
            currentTrackID = id
            loadArtwork(forID: id)
        }
    }

    /// Full refresh, used at startup and after Spotify relaunches.
    func sync() {
        guard isRunning else { reset(.notRunning); return }
        guard let state = run("return player state as text")?.stringValue else { reset(.stopped); return }
        if state == "stopped" { reset(.stopped); refreshVolume(); return }
        status = (state == "playing") ? .playing : .paused
        if let list = run("return {name of current track, artist of current track, id of current track}") {
            title = list.atIndex(1)?.stringValue ?? ""
            artist = list.atIndex(2)?.stringValue ?? ""
            let id = list.atIndex(3)?.stringValue ?? ""
            if id != currentTrackID {
                currentTrackID = id
                loadArtwork(forID: id)
            }
        }
        refreshVolume()
    }

    private func reset(_ newStatus: Status) {
        status = newStatus
        title = ""
        artist = ""
        artwork = nil
        currentTrackID = ""
    }

    private func loadArtwork(forID id: String) {
        guard let s = run("return artwork url of current track")?.stringValue,
              let url = URL(string: s), url.scheme?.hasPrefix("http") == true else {
            artwork = nil   // no artwork: the view shows its placeholder
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self, self.currentTrackID == id else { return }  // ignore stale downloads
                self.artwork = data.flatMap { NSImage(data: $0) }
            }
        }.resume()
    }

    // MARK: Commands

    func previous() { _ = run("previous track") }
    func playPause() { _ = run("playpause") }
    func next() { _ = run("next track") }

    func refreshVolume() {
        if let v = run("return sound volume")?.int32Value { volume = Double(v) }
    }

    func setVolume(_ v: Double) {
        volume = v
        let now = Date()
        if now.timeIntervalSince(lastVolumeSend) > 0.1 {   // throttle while dragging
            lastVolumeSend = now
            _ = run("set sound volume to \(Int(v))")
        }
    }

    func commitVolume() {
        lastVolumeSend = Date()
        _ = run("set sound volume to \(Int(volume))")
    }

    // MARK: AppleScript (never runs unless Spotify is already running, so it can't launch it)

    private func run(_ body: String) -> NSAppleEventDescriptor? {
        guard isRunning else { return nil }
        let source = "tell application id \"\(bundleID)\"\n\(body)\nend tell"
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}

// MARK: - View

struct MiniPlayerView: View {
    @ObservedObject var service: SpotifyService
    @State private var hovering = false

    private let side: CGFloat = 240
    private let showTitleStrip = true   // minimal always-on title line; set false for art only

    var body: some View {
        ZStack {
            artworkLayer
            if showTitleStrip && !hovering && service.isActive {
                titleStrip.transition(.opacity)
            }
            if hovering && service.isActive {
                controlsLayer.transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) { hovering = h }
            if h { service.refreshVolume() }
        }
    }

    private var artworkLayer: some View {
        Group {
            if let art = service.artwork {
                Image(nsImage: art).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.gray.opacity(0.55), .black.opacity(0.85)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 8) {
                        Image(systemName: "music.note").font(.system(size: 40))
                        if !service.isActive {
                            Text(service.status == .notRunning ? "Spotify isn't running" : "Nothing playing")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(width: side, height: side)
        .clipped()
    }

    /// Minimal always-on line: a soft fade at the bottom with "Title  Artist" on one line.
    private var titleStrip: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .frame(height: 56)
                .frame(maxHeight: .infinity, alignment: .bottom)
            (Text(service.title).fontWeight(.semibold)
                + Text("  \(service.artist)").foregroundColor(.white.opacity(0.7)))
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .frame(width: side, height: side, alignment: .bottomLeading)
        .allowsHitTesting(false)
    }

    private var controlsLayer: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.8)],
                           startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom)
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text(service.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text(service.artist)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                HStack(spacing: 24) {
                    controlButton("backward.fill", size: 18) { service.previous() }
                    controlButton(service.status == .playing ? "pause.fill" : "play.fill", size: 26) { service.playPause() }
                    controlButton("forward.fill", size: 18) { service.next() }
                }
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill").font(.system(size: 10))
                    Slider(value: volumeBinding, in: 0...100, onEditingChanged: { editing in
                        if !editing { service.commitVolume() }
                    })
                    .tint(.white)
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 10))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { service.volume }, set: { service.setVolume($0) })
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Desktop-level window

/// Lets the first click act on a control even though the panel isn't the key window.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

enum MiniPlayerWindow {
    private static var panel: NSPanel?
    private static let service = SpotifyService()

    static func show() {
        guard panel == nil else { return }
        let side: CGFloat = 240
        let p = NSPanel(contentRect: NSRect(x: 200, y: 200, width: side, height: side),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.isMovableByWindowBackground = true
        p.contentView = FirstMouseHostingView(rootView: MiniPlayerView(service: service))

        // Remember position between launches.
        if !p.setFrameUsingName("MiniPlayer") { p.center() }
        p.setFrameAutosaveName("MiniPlayer")

        p.orderFrontRegardless()
        panel = p
    }
    static func toggle() {
        guard let p = panel else { show(); return }
        if p.isVisible { p.orderOut(nil) } else { p.orderFrontRegardless() }
    }
}
