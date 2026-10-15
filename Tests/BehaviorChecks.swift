import Foundation
import AppKit

// Run with Tests/run.sh. Uses production geometry and an isolated HTTP session/defaults suite.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requests = 0
    nonisolated(unsafe) static var fail = false
    nonisolated(unsafe) static var observation = Date()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests += 1
        if Self.fail {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let body: String
        if request.url!.host!.contains("geocoding") {
            body = #"{"results":[{"name":"Test City","latitude":27.7,"longitude":85.3}]}"#
        } else {
            assert(request.url!.query!.contains("timeformat=unixtime"))
            body = "{\"current\":{\"time\":\(Self.observation.timeIntervalSince1970),\"temperature_2m\":22,\"weather_code\":1,\"is_day\":1}}"
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
                                                            httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main
struct BehaviorChecks {
    @MainActor static func main() async {
        _ = NSApplication.shared
        let panel = LayoutPanel(contentRect: CGRect(x: 0, y: 0, width: 94, height: 94),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isReleasedWhenClosed = false
        let layout = LayoutController.shared
        layout.register(panel)
        assert(!panel.isMovable && !panel.isMovableByWindowBackground, "Starts locked")
        layout.isEditing = true
        assert(panel.isMovable && panel.isMovableByWindowBackground, "Editing enables dragging")
        layout.isEditing = false
        assert(!panel.isMovable && !panel.isMovableByWindowBackground, "Lock disables dragging")
        panel.close()
        let screen = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let neighbor = CGRect(x: -1000, y: 400, width: 204, height: 94)
        let proposed = CGRect(x: -777, y: 405, width: 94, height: 94)
        let snapped = LayoutSnap.origin(for: proposed, near: [neighbor], visibleFrame: screen, freely: false)
        assert(snapped == CGPoint(x: -780, y: 400), "16-point gap and row alignment")
        assert(LayoutSnap.origin(for: proposed, near: [neighbor], visibleFrame: screen, freely: true) == proposed.origin, "Option bypass")
        let above = CGRect(x: -996, y: 515, width: 204, height: 204)
        assert(LayoutSnap.origin(for: above, near: [neighbor], visibleFrame: screen, freely: false) == CGPoint(x: -1000, y: 510), "Vertical gap and unequal sizes")
        let far = CGRect(x: -600, y: 100, width: 94, height: 94)
        assert(LayoutSnap.origin(for: far, near: [neighbor], visibleFrame: screen, freely: false) == far.origin, "No remote attraction")
        let edge = CGRect(x: -1420, y: 793, width: 94, height: 94)
        assert(LayoutSnap.origin(for: edge, near: [], visibleFrame: screen, freely: false) == CGPoint(x: -1424, y: 790), "Negative screen origin")
        assert(WeatherInfo.describe(code: 1, isDay: true).label == "Mainly clear")
        assert(WeatherInfo.describe(code: 2, isDay: false).symbol == "cloud.moon.fill")

        let suite = "WidgionChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("Test City", forKey: "weather.city")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        let service = WeatherService(defaults: defaults, session: URLSession(configuration: configuration))
        await service.refresh()
        guard case .ready(let fresh, stale: false) = service.state else { fatalError("Expected fresh weather") }
        assert(fresh.observedAt != nil)
        assert(fresh.isStale(at: .now.addingTimeInterval(1900)))
        assert(StubProtocol.requests == 2)
        await service.refresh()
        assert(StubProtocol.requests == 2, "Fresh cache avoids HTTP")
        await service.refresh(force: true)
        assert(StubProtocol.requests == 4, "Wake/manual refresh bypasses fresh cache")
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        for _ in 0..<100 {
            if StubProtocol.requests == 6 && !service.isRefreshing { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        assert(StubProtocol.requests == 6, "Wake notification forces a refresh")
        StubProtocol.fail = true
        await service.refresh(force: true)
        guard case .ready(_, stale: true) = service.state else { fatalError("Failed refresh must label saved data") }
        defaults.set("Other City", forKey: "weather.city")
        await service.refresh()
        guard case .failed = service.state else { fatalError("Never show previous city's cache") }
        defaults.set("", forKey: "weather.city")
        await service.refresh()
        guard case .notFound = service.state else { fatalError("Empty city") }
        StubProtocol.fail = false
        StubProtocol.observation = .now.addingTimeInterval(-3600)
        defaults.set("Test City", forKey: "weather.city")
        await service.refresh(force: true)
        guard case .ready(_, stale: true) = service.state else { fatalError("Old upstream timestamp must stay stale after successful fetch") }
        assert(!service.isRefreshing)
        print("Passed: layout lock, snapping, Option bypass, screen edges, weather cache, wake refresh, stale fallback, city isolation, condition mapping.")
    }
}
