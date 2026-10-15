import AppKit
import Combine

/// Shared by Widgion and its Docky bundle. Never reads macOS's global Now Playing source.
@MainActor
final class SpotifyService: ObservableObject {
    enum Status { case notRunning, stopped, playing, paused }
    @Published var status: Status = .notRunning
    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var artwork: NSImage?
    @Published var volume: Double = 50
    @Published private(set) var duration: Double = 0
    @Published private(set) var position: Double = 0
    @Published private(set) var errorMessage: String?
    private var positionDate = Date()
    private var currentTrackID = ""
    private var artworkURL = ""
    private var artworkTask: Task<Void, Never>?
    private var observers: [AnyCancellable] = []
    private var pollTask: Task<Void, Never>?
    private var refreshing = false
    private var needsRefresh = false
    private var lastVolumeSend = Date.distantPast
    private var generation = 0
    private var observing = false
    private let bundleID = "com.spotify.client"

    var isActive: Bool { status == .playing || status == .paused }

    init(observePlayback: Bool = true) {
        if observePlayback { startObserving() }
    }

    /// Start once, even when Docky creates several compact/expanded views.
    func startObserving() {
        guard !observing else { return }
        observing = true
        let dnc = DistributedNotificationCenter.default()
        observers.append(dnc.publisher(for: Notification.Name("com.spotify.client.PlaybackStateChanged"))
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.sync() })
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] notification in
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == self.bundleID else { return }
                if name == NSWorkspace.didTerminateApplicationNotification {
                    self.generation += 1
                    self.reset(.notRunning)
                } else { self.sync() }
            })
        }
        observers.append(center.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.sync() })
        sync()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                self?.sync()
            }
        }
    }

    deinit { pollTask?.cancel(); artworkTask?.cancel() }

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    func elapsed(at date: Date = .now) -> Double {
        min(max(position + (status == .playing ? max(0, date.timeIntervalSince(positionDate)) : 0), 0), duration)
    }

    func sync() {
        guard isRunning else { reset(.notRunning); return }
        guard !refreshing else { needsRefresh = true; return }
        refreshing = true
        let requestGeneration = generation
        Task { [weak self] in
            let reply = await SpotifyScript.execute(Self.snapshotScript)
            guard let self else { return }
            self.refreshing = false
            if requestGeneration == self.generation {
                if let values = reply.values { self.apply(values) }
                else { self.reportError(reply.errorNumber) }
            }
            if self.needsRefresh { self.needsRefresh = false; self.sync() }
        }
    }

    private static let snapshotScript = """
        set playbackState to player state as text
        if playbackState is "stopped" then return {playbackState}
        return {playbackState, name of current track, artist of current track, album of current track, ¬
            duration of current track as text, player position as text, sound volume as text, ¬
            id of current track, artwork url of current track}
        """

    /// Values are copied out of AppleScript descriptors on its serial queue.
    func apply(_ values: [String]) {
        guard let playback = values.first else { return }
        errorMessage = nil
        if playback == "notRunning" { reset(.notRunning); return }
        guard playback == "playing" || playback == "paused", values.count == 9 else {
            reset(.stopped)
            return
        }
        status = playback == "playing" ? .playing : .paused
        title = values[1]; artist = values[2]; album = values[3]
        duration = max(0, Self.number(values[4]) / 1000) // Spotify reports track duration in milliseconds.
        position = min(max(0, Self.number(values[5])), duration)
        positionDate = .now
        volume = min(max(Self.number(values[6]), 0), 100)
        if values[7] != currentTrackID || values[8] != artworkURL {
            currentTrackID = values[7]
            artworkURL = values[8]
            artwork = nil // Never leave the previous track's art beside a new title.
            loadArtwork(id: currentTrackID, source: artworkURL)
        }
    }

    private static func number(_ value: String) -> Double {
        Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func reset(_ newStatus: Status) {
        status = newStatus; title = ""; artist = ""; album = ""
        artwork = nil; currentTrackID = ""; artworkURL = ""
        duration = 0; position = 0; errorMessage = nil
        artworkTask?.cancel()
    }

    private func reportError(_ number: Int?) {
        errorMessage = number == -1743
            ? "Allow this app to control Spotify in System Settings → Privacy & Security → Automation."
            : "Spotify isn’t responding. Try again in a moment."
    }

    private func loadArtwork(id: String, source: String) {
        artworkTask?.cancel()
        guard let url = URL(string: source), url.scheme == "https" else { return }
        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15))
                guard !Task.isCancelled, let self, self.currentTrackID == id, self.artworkURL == source,
                      let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return }
                self.artwork = NSImage(data: data)
            } catch { /* The placeholder remains available when artwork is offline. */ }
        }
    }

    func openSpotify() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        } else if let url = URL(string: "https://open.spotify.com") { NSWorkspace.shared.open(url) }
    }

    private func command(_ body: String) {
        guard isRunning else { reset(.notRunning); return }
        generation += 1 // An older snapshot must not overwrite a seek or playback action.
        Task { [weak self] in
            let reply = await SpotifyScript.execute(body)
            guard let self else { return }
            if reply.errorNumber != nil { self.reportError(reply.errorNumber) }
            else { self.sync() }
        }
    }

    func previous() { command("previous track") }
    func playPause() { command("playpause") }
    func next() { command("next track") }
    func refreshVolume() { sync() }

    func seek(to seconds: Double) {
        guard seconds.isFinite, duration > 0, isActive else { return }
        let value = min(max(seconds, 0), duration)
        position = value; positionDate = .now
        command("set player position to \(value)")
    }

    func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(max(value, 0), 100)
        if Date().timeIntervalSince(lastVolumeSend) > 0.15 {
            lastVolumeSend = .now
            command("set sound volume to \(Int(volume))")
        }
    }

    func commitVolume() {
        lastVolumeSend = .now
        command("set sound volume to \(Int(volume))")
    }
}

/// Serial, bounded Apple Events keep Spotify latency off Docky's main thread.
private enum SpotifyScript {
    struct Reply: Sendable { let values: [String]?; let errorNumber: Int? }
    nonisolated private static let queue = DispatchQueue(label: "com.zyotis.widgion.spotify-events")

    nonisolated static func execute(_ body: String) async -> Reply {
        await withCheckedContinuation { continuation in
            queue.async {
                let source = """
                if application id "com.spotify.client" is not running then return {"notRunning"}
                with timeout of 3 seconds
                    tell application id "com.spotify.client"
                        \(body)
                    end tell
                end timeout
                """
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                let values: [String]?
                if let result, result.numberOfItems > 0 {
                    values = (1...result.numberOfItems).map { result.atIndex($0)?.stringValue ?? "" }
                } else { values = result.map { [$0.stringValue ?? ""] } }
                continuation.resume(returning: Reply(values: values,
                    errorNumber: error?[NSAppleScript.errorNumber] as? Int))
            }
        }
    }
}
