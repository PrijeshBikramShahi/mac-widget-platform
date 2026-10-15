import AppKit

@main struct ServiceChecks {
    @MainActor static func main() {
        let service = SpotifyService(observePlayback: false)
        service.apply(["playing", "Track", "Artist", "Album", "232000", "4.5", "65", "spotify:track:one", ""])
        assert(service.isActive && service.status == .playing)
        assert(service.duration == 232 && service.position == 4.5 && service.volume == 65)
        assert(service.elapsed(at: .now.addingTimeInterval(10)) >= 14.5)
        assert(service.elapsed(at: .now.addingTimeInterval(300)) == 232)
        service.apply(["paused", "Next", "Artist", "Album", "180000", "10,5", "250", "spotify:track:two", ""])
        assert(service.status == .paused && service.title == "Next")
        assert(service.elapsed(at: .now.addingTimeInterval(300)) == 10.5)
        assert(service.volume == 100 && service.artwork == nil)
        service.apply(["stopped"])
        assert(!service.isActive && service.title.isEmpty && service.duration == 0)
        service.apply(["notRunning"])
        assert(service.status == .notRunning)
        assert(DockySpotifyView.timestamp(232) == "3:52")
        assert(DockySpotifyView.timestamp(-1) == "0:00")
        assert(DockySpotifyView.timestamp(.nan) == "0:00")
        print("Passed Spotify state, timing, track changes, locale numbers, stopped/closed states, and timestamp checks.")
    }
}
