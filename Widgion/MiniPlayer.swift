import SwiftUI
import AppKit
import Combine

// Spotify mini-player: album art, hover to reveal previous / play-pause / next + volume.
// Lives in a desktop-level panel (above wallpaper, below app windows).
// Add to the Widgion APP target. Needs the entitlements already set up:
//  - Apple Events exception for com.spotify.client
//  - com.apple.security.network.client

// SpotifyService.swift is shared with the Docky widget.

// MARK: - View

struct MiniPlayerView: View {
    @ObservedObject var service: SpotifyService
    @AppStorage("player.size") private var size = PlayerSize.large
    @AppStorage("player.artworkOnlyWhenIdle") private var artworkOnlyWhenIdle = false
    @State private var hovering = false
    @State private var editingVolume = false

    private var controlsVisible: Bool { hovering || editingVolume }

    var body: some View {
        Group {
            if size == .wide {
                wideLayout
            } else {
                squareLayout
            }
        }
        .frame(width: size.points.width, height: size.points.height)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: WidgetGrid.cornerRadius, style: .continuous))
        .overlay { LayoutOutline() }
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) { hovering = h }
            if h { service.refreshVolume() }
        }
        .contextMenu {
            Button("Open Spotify", systemImage: "arrow.up.forward.app") { service.openSpotify() }
            Divider()
            Button(service.status == .playing ? "Pause" : "Play",
                   systemImage: service.status == .playing ? "pause.fill" : "play.fill") { service.playPause() }
                .disabled(service.status == .notRunning)
            Button("Previous track", systemImage: "backward.fill") { service.previous() }
                .disabled(!service.isActive)
            Button("Next track", systemImage: "forward.fill") { service.next() }
                .disabled(!service.isActive)
            Divider()
            Picker("Size", selection: $size) {
                ForEach(PlayerSize.allCases) { Text($0.label).tag($0) }
            }
            Menu("Volume") {
                ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                    Button("\(value)%") {
                        service.setVolume(Double(value))
                        service.commitVolume()
                    }
                }
            }
            .disabled(!service.isActive)
        }
    }

    private func artwork(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let art = service.artwork {
                Image(nsImage: art).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(white: 0.28), Color(white: 0.09)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: min(width, height) * 0.25))
                            .foregroundStyle(.white.opacity(0.45))
                    }
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var squareLayout: some View {
        let small = size == .small
        return ZStack(alignment: .bottom) {
            artwork(width: size.points.width, height: size.points.height)
                .onTapGesture(count: 2) { service.openSpotify() }
                .help("Double-click to open Spotify. Right-click for playback actions.")
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.55), location: 0.45),
                .init(color: .black.opacity(0.82), location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .frame(height: small ? 44 : size.points.height / 3)
                .opacity(artworkOnlyWhenIdle && !controlsVisible && service.isActive ? 0 : 1)
                .allowsHitTesting(false)
            if service.isActive {
                // Both layers share the bottom inset; hidden controls reserve no space below the title.
                ZStack(alignment: .bottomLeading) {
                    trackInfo(titleSize: small ? 10 : 12, showArtist: !small)
                        .opacity(!artworkOnlyWhenIdle && !controlsVisible ? 1 : 0)
                        .allowsHitTesting(!artworkOnlyWhenIdle && !controlsVisible)
                        .accessibilityHidden(artworkOnlyWhenIdle || controlsVisible)
                    HStack(spacing: 10) {
                        transport(compact: small)
                        if !small { volumeSlider }
                    }
                    .frame(height: small ? 24 : 32)
                    .opacity(controlsVisible ? 1 : 0)
                    .allowsHitTesting(controlsVisible)
                    .accessibilityHidden(!controlsVisible)
                }
                .padding(.horizontal, small ? 10 : 14)
                .padding(.bottom, small ? 10 : 16)
            } else {
                Text(service.status == .notRunning ? "Spotify isn’t running" : "Nothing playing")
                    .font(.system(size: small ? 10 : 12, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(small ? 10 : 16)
            }
        }
    }

    private var wideLayout: some View {
        ZStack {
            artwork(width: size.points.width, height: size.points.height)
                .blur(radius: 18)
                .overlay(.black.opacity(0.6))
            HStack(spacing: 10) {
                artwork(width: 72, height: 72)
                    .onTapGesture(count: 2) { service.openSpotify() }
                    .help("Double-click to open Spotify")
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    if service.isActive {
                        trackInfo(titleSize: 11, showArtist: true)
                        transport(compact: true)
                        volumeSlider
                    } else {
                        Text(service.status == .notRunning ? "Spotify isn’t running" : "Nothing playing")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11)
        }
    }

    private func trackInfo(titleSize: CGFloat, showArtist: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(service.title.isEmpty ? "Unknown track" : service.title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .lineLimit(size == .large ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .help(service.title)
            if showArtist {
                Text(service.artist)
                    .font(.system(size: size == .wide ? 9 : 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .help(service.artist)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
    }

    private func transport(compact: Bool) -> some View {
        HStack(spacing: 0) {
            controlButton("backward.fill", label: "Previous track", compact: compact) { service.previous() }
            Spacer(minLength: 0)
            controlButton(service.status == .playing ? "pause.fill" : "play.fill",
                          label: service.status == .playing ? "Pause" : "Play",
                          compact: compact, primary: true) { service.playPause() }
            Spacer(minLength: 0)
            controlButton("forward.fill", label: "Next track", compact: compact) { service.next() }
        }
        .frame(maxWidth: compact ? .infinity : 100)
    }

    private var volumeSlider: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill").font(.system(size: 8))
                .accessibilityHidden(true)
            PlayerVolumeSlider(value: volumeBinding, onEditingChanged: { editingVolume = $0 },
                               onCommit: { service.commitVolume() })
        }
        .frame(height: 14)
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { service.volume }, set: { service.setVolume($0) })
    }

    private func controlButton(_ symbol: String, label: String, compact: Bool,
                               primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? (primary ? 13 : 10) : (primary ? 16 : 12), weight: .semibold))
                .frame(width: compact ? 24 : (primary ? 32 : 28), height: compact ? 24 : 32)
                .background {
                    if primary { Circle().fill(.white.opacity(0.14)) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
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
    private static var settingsObserver: NSObjectProtocol?
    private static var appliedEnabled = true

    static func show() {
        guard panel == nil else { return }
        let size = Prefs.playerSize.points
        let p = LayoutPanel(contentRect: NSRect(origin: NSPoint(x: 200, y: 200), size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        LayoutController.shared.register(p)
        let host = FirstMouseHostingView(rootView: MiniPlayerView(service: service))
        host.sizingOptions = []
        p.contentView = host

        // Remember position between launches.
        if !p.setFrameUsingName("MiniPlayer") { p.center() }
        p.setFrameAutosaveName("MiniPlayer")

        panel = p
        resizeToPreference() // A saved frame may still contain the old 240-point size.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                resizeToPreference()
                let enabled = UserDefaults.standard.bool(forKey: "player.enabled")
                if enabled != appliedEnabled {
                    appliedEnabled = enabled
                    if enabled { panel?.orderFrontRegardless() } else { panel?.orderOut(nil) }
                }
            }
        }
        appliedEnabled = UserDefaults.standard.bool(forKey: "player.enabled")
        if appliedEnabled { p.orderFrontRegardless() }
    }
    private static func resizeToPreference() {
        guard let panel else { return }
        let size = Prefs.playerSize.points
        let frame = panel.frame
        guard frame.size != size else { return }
        // Anchor the top-left corner, matching the other desktop widgets.
        panel.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
    }

    static func toggle() {
        guard let p = panel else { show(); return }
        UserDefaults.standard.set(!p.isVisible, forKey: "player.enabled")
    }
}
