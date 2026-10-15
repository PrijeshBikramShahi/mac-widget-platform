import SwiftUI
import AppKit
import Combine

// Spotify prototype, remaining gates:
//  3. Track-change detection (distributed notification, with optional polling for comparison)
//  4. Album artwork loading with fallback
//  5. Spotify quit and relaunch recovery
// Requires SpotifyGates.swift (uses SpotifyGate). Add to the CWTest APP target.
// In ContentView, show ProbeView4().

final class SpotifyProbe: ObservableObject {
    @Published var log: [String] = []
    @Published var artwork: NSImage?
    @Published var polling = false

    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var timer: Timer?
    private var lastPolled = ""
    private let bundleID = SpotifyGate.bundleID
    private let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func note(_ s: String) {
        log.insert("\(timeFormat.string(from: Date()))  \(s)", at: 0)
        if log.count > 200 { log.removeLast() }
    }

    // MARK: Listening

    func start() {
        guard observers.isEmpty else { note("Already listening"); return }

        let dnc = DistributedNotificationCenter.default()
        let token = dnc.addObserver(forName: Notification.Name("com.spotify.client.PlaybackStateChanged"),
                                    object: nil, queue: .main) { [weak self] n in
            guard let self else { return }
            let info = n.userInfo ?? [:]
            let keys = info.keys.map { "\($0)" }.sorted().joined(separator: ",")
            self.note("NOTIFICATION state=\(info["Player State"] ?? "nil") track=\(info["Name"] ?? "nil") userInfo keys=[\(keys)]")
            self.refreshArtwork(reason: "notification")
        }
        observers.append((dnc, token))

        let ws = NSWorkspace.shared.notificationCenter
        let events: [(Notification.Name, String)] = [
            (NSWorkspace.didLaunchApplicationNotification, "LAUNCHED"),
            (NSWorkspace.didTerminateApplicationNotification, "QUIT"),
        ]
        for (name, label) in events {
            let t = ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
                guard let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == SpotifyGate.bundleID else { return }
                self?.note("Spotify \(label)")
                if label == "LAUNCHED" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.refreshArtwork(reason: "3 s after relaunch")
                    }
                } else {
                    self?.artwork = nil
                }
            }
            observers.append((ws, t))
        }
        note("Listening for Spotify notifications and launch/quit events")
    }

    // MARK: Polling (comparison only)

    func togglePolling() {
        polling.toggle()
        timer?.invalidate()
        timer = nil
        guard polling else { note("Polling off"); return }
        note("Polling every 2 s")
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func poll() {
        guard SpotifyGate.isRunning else {
            if lastPolled != "not running" { note("POLL: Spotify not running"); lastPolled = "not running" }
            return
        }
        let r = script("return (name of current track) & \" | \" & (player state as text)")
        let current = r.value ?? "error \(r.error ?? "?")"
        if current != lastPolled {
            note("POLL saw change: \(current) [\(r.ms) ms]")
            lastPolled = current
        }
    }

    // MARK: Artwork

    func refreshArtwork(reason: String) {
        guard SpotifyGate.isRunning else {
            note("[\(reason)] Spotify not running, nothing fetched (and nothing launched)")
            artwork = nil
            return
        }
        let r = script("return (name of current track) & \" | \" & (artwork url of current track)")
        if let e = r.error {
            note("[\(reason)] script error \(e) [\(r.ms) ms]")
            artwork = nil
            return
        }
        guard let value = r.value else { note("[\(reason)] empty result"); artwork = nil; return }
        let parts = value.components(separatedBy: " | ")
        let urlString = parts.last ?? ""
        let name = parts.dropLast().joined(separator: " | ")
        note("[\(reason)] track=\(name) artwork=\(urlString) [\(r.ms) ms]")

        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            note("No usable artwork URL, showing placeholder")
            artwork = nil
            return
        }
        let start = Date()
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                if let data, let image = NSImage(data: data) {
                    self?.artwork = image
                    self?.note("artwork loaded \(Int(image.size.width))x\(Int(image.size.height)), \(data.count / 1024) KB, \(ms) ms")
                } else {
                    self?.artwork = nil
                    self?.note("artwork FAILED: \(error?.localizedDescription ?? "bad image data") [\(ms) ms]")
                }
            }
        }.resume()
    }

    // MARK: Script helper (only ever called when Spotify is running)

    private func script(_ body: String) -> (value: String?, error: String?, ms: Int) {
        let source = "tell application id \"\(bundleID)\"\n\(body)\nend tell"
        let start = Date()
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        if let error {
            return (nil, "\(error["NSAppleScriptErrorNumber"] ?? "?"): \(error["NSAppleScriptErrorMessage"] ?? "unknown")", ms)
        }
        return (result?.stringValue, nil, ms)
    }
}

struct ProbeView4: View {
    @StateObject private var probe = SpotifyProbe()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let art = probe.artwork {
                        Image(nsImage: art).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Rectangle().fill(.quaternary)
                            Image(systemName: "music.note").font(.system(size: 36)).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Button("Start listening") { probe.start() }
                    Button("Refresh now") { probe.refreshArtwork(reason: "manual") }
                    Button(probe.polling ? "Stop polling" : "Poll every 2 s (comparison)") { probe.togglePolling() }
                    Button("Clear log") { probe.log.removeAll() }
                }
            }

            Divider()
            ScrollView {
                Text(probe.log.joined(separator: "\n"))
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(minWidth: 680, minHeight: 460)
    }
}
