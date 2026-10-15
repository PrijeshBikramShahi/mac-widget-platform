import AppKit
import SwiftUI

struct DockySpotifyView: View {
    @ObservedObject var service: SpotifyService
    let cornerRadius: CGFloat
    let span: Int
    let expanded: Bool
    var artworkBackground = true
    var connectOnAppear = true
    @State private var hovering = false
    @State private var seeking = false
    @State private var seekPosition = 0.0
    @State private var volumeEditing = false
    @State private var draftVolume = 50.0
    @State private var backgroundTint = Color(red: 0.10, green: 0.12, blue: 0.11)

    var body: some View {
        GeometryReader { geometry in
            // Some Docky versions retain a hosted view while changing its tile span.
            // Derive compact layout from the actual bounds as well as the creation flags.
            let size = geometry.size
            let isExpanded = expanded || size.height > 115
            let ratio = size.width / max(size.height, 1)
            ZStack {
                background
                if service.errorMessage != nil && !service.isActive {
                    unavailable(size: size, message: "Connect Spotify", symbol: "exclamationmark.circle")
                } else if service.status == .notRunning {
                    unavailable(size: size, message: "Open Spotify", symbol: "music.note")
                } else if !service.isActive {
                    unavailable(size: size, message: "Play in Spotify", symbol: "play.fill")
                } else if isExpanded {
                    expandedPlayer(size: size)
                } else if ratio < 1.4 {
                    compactArtwork
                } else {
                    compactPlayer(size: size, showTitle: ratio > 2.65)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if service.errorMessage != nil && service.isActive {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11)).foregroundStyle(.yellow).padding(6)
                        .help(service.errorMessage ?? "")
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onHover { hovering = $0 }
        .onAppear { if connectOnAppear { service.startObserving() } }
        .onReceive(service.$artwork) { backgroundTint = Self.tint(for: $0) }
        .contextMenu {
            Button("Open Spotify", systemImage: "arrow.up.forward.app") { service.openSpotify() }
            Divider()
            Button(service.status == .playing ? "Pause" : "Play",
                   systemImage: service.status == .playing ? "pause.fill" : "play.fill") { service.playPause() }
                .disabled(service.status == .notRunning)
            Button("Previous track", systemImage: "backward.fill") { service.previous() }.disabled(!service.isActive)
            Button("Next track", systemImage: "forward.fill") { service.next() }.disabled(!service.isActive)
            Menu("Volume") {
                ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                    Button("\(value)%") { service.setVolume(Double(value)); service.commitVolume() }
                }
            }.disabled(!service.isActive)
            Divider()
            Button("Refresh Spotify", systemImage: "arrow.clockwise") { service.sync() }
        }
    }

    private var background: some View {
        (artworkBackground ? backgroundTint : Color(red: 0.10, green: 0.12, blue: 0.11))
            .allowsHitTesting(false)
    }

    /// Sample once per artwork update; keep enough contrast for white text at every size.
    private static func tint(for image: NSImage?) -> Color {
        guard let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return Color(red: 0.10, green: 0.12, blue: 0.11)
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        pixel.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return Color(red: Double(pixel[0]) / 255 * 0.36 + 0.04,
                     green: Double(pixel[1]) / 255 * 0.36 + 0.04,
                     blue: Double(pixel[2]) / 255 * 0.36 + 0.04)
    }

    private func artwork(radius: CGFloat) -> some View {
        GeometryReader { geometry in
            Group {
                if let image = service.artwork { Image(nsImage: image).resizable().scaledToFill() }
                else {
                    Color.white.opacity(0.07).overlay {
                        Image(systemName: "music.note").font(.system(size: geometry.size.height * 0.3))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityLabel("Album artwork")
    }

    private var compactArtwork: some View {
        artwork(radius: cornerRadius)
            .overlay {
                Button { service.playPause() } label: {
                    Image(systemName: service.status == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.5), in: Circle())
                        .opacity(hovering ? 1 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(service.status == .playing ? "Pause Spotify" : "Play Spotify")
            }
            .help("\(service.title) — \(service.artist)")
    }

    private func compactPlayer(size: CGSize, showTitle: Bool) -> some View {
        let inset = max(4, min(9, size.height * 0.1))
        let artSize = max(20, size.height - inset * 2)
        let buttonSize = min(28, max(18, size.height * 0.32))
        return HStack(spacing: inset) {
            artwork(radius: max(5, cornerRadius - inset))
                .frame(width: artSize, height: artSize)
            if showTitle {
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.title).font(.system(size: min(13, size.height * 0.2), weight: .semibold))
                    Text(service.artist).font(.system(size: min(11, size.height * 0.17)))
                        .foregroundStyle(.white.opacity(0.65))
                }.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
            transport(buttonSize: buttonSize, includePrevious: !showTitle || size.width > 260)
                .frame(maxWidth: showTitle ? nil : .infinity)
        }
        .padding(inset)
    }

    private func expandedPlayer(size: CGSize) -> some View {
        let padding = max(10, min(18, size.height * 0.08))
        let artSize = max(50, min(size.height - padding * 2, size.width * 0.34))
        return HStack(spacing: padding) {
            Button { service.openSpotify() } label: {
                artwork(radius: max(10, cornerRadius * 0.5))
                    .frame(width: artSize, height: artSize)
            }.buttonStyle(.plain).help("Open Spotify")
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(service.title).font(.system(size: min(20, size.height * 0.105), weight: .semibold))
                            .lineLimit(2)
                        Text([service.artist, service.album].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: min(13, size.height * 0.07)))
                            .foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button { service.openSpotify() } label: {
                        Image(systemName: "arrow.up.forward.app").font(.system(size: 13))
                    }.buttonStyle(.plain).help("Open Spotify").accessibilityLabel("Open Spotify")
                }
                Spacer(minLength: 0)
                HStack {
                    transport(buttonSize: min(36, size.height * 0.2), includePrevious: true)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 9)).accessibilityHidden(true)
                        Slider(value: Binding(get: { volumeEditing ? draftVolume : service.volume },
                                              set: { draftVolume = $0 }), in: 0...100) { editing in
                            if editing { draftVolume = service.volume }
                            volumeEditing = editing
                            if !editing { service.setVolume(draftVolume); service.commitVolume() }
                        }
                        .controlSize(.mini).accessibilityLabel("Spotify volume")
                    }.frame(width: min(80, size.width * 0.18))
                }
                progress
            }
        }
        .padding(padding)
    }

    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = seeking ? seekPosition : service.elapsed(at: context.date)
            VStack(spacing: 1) {
                Slider(value: Binding(get: { min(position, max(service.duration, 1)) },
                                      set: { seekPosition = $0 }), in: 0...max(service.duration, 1)) { editing in
                    if editing { seekPosition = service.elapsed() }
                    seeking = editing
                    if !editing { service.seek(to: seekPosition) }
                }
                .controlSize(.mini).disabled(service.duration <= 0)
                .accessibilityLabel("Playback position")
                HStack {
                    Text(Self.timestamp(position))
                    Spacer()
                    Text("−\(Self.timestamp(max(0, service.duration - position)))")
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func transport(buttonSize: CGFloat, includePrevious: Bool) -> some View {
        HStack(spacing: 2) {
            if includePrevious {
                control("backward.fill", "Previous track", size: buttonSize, action: service.previous)
            }
            control(service.status == .playing ? "pause.fill" : "play.fill",
                    service.status == .playing ? "Pause" : "Play", size: buttonSize,
                    primary: true, action: service.playPause)
            control("forward.fill", "Next track", size: buttonSize, action: service.next)
        }
    }

    private func control(_ symbol: String, _ label: String, size: CGFloat,
                         primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size * (primary ? 0.45 : 0.36), weight: .semibold))
                .frame(width: size, height: size)
                .background(primary ? .white.opacity(0.13) : .clear, in: Circle())
                .contentShape(Circle())
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }

    private func unavailable(size: CGSize, message: String, symbol: String) -> some View {
        Button { service.openSpotify(); service.sync() } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 22))
                if size.width / max(size.height, 1) > 1.4 {
                    Text(message).font(.system(size: 12, weight: .medium)).lineLimit(1)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(8)
        }.buttonStyle(.plain).accessibilityLabel(message)
            .help(service.errorMessage ?? message)
    }

    static func timestamp(_ seconds: Double) -> String {
        let seconds = seconds.isFinite ? Int(max(0, seconds)) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
