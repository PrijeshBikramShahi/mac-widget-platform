import Foundation
import Combine
import AppKit

struct WeatherSnapshot: Codable {
    let city: String
    let place: String
    let tempC: Double
    let code: Int
    let isDay: Bool
    let fetchedAt: Date
    var observedAt: Date? = nil

    func isStale(at now: Date = .now) -> Bool {
        guard let observedAt else { return true }
        return now.timeIntervalSince(observedAt) >= WeatherService.maxAge
            || now.timeIntervalSince(fetchedAt) >= WeatherService.maxAge
    }
}

enum WeatherInfo {
    static func describe(code: Int, isDay: Bool) -> (label: String, symbol: String) {
        switch code {
        case 0: return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1: return ("Mainly clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 2: return ("Partly cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51...57: return ("Drizzle", "cloud.drizzle.fill")
        case 61...67: return ("Rain", "cloud.rain.fill")
        case 71...77: return ("Snow", "cloud.snow.fill")
        case 80...82: return ("Showers", "cloud.heavyrain.fill")
        case 85, 86: return ("Snow showers", "cloud.snow.fill")
        case 95...99: return ("Thunderstorm", "cloud.bolt.rain.fill")
        default: return ("Unknown", "questionmark.circle")
        }
    }
}

@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()
    nonisolated static let maxAge: TimeInterval = 30 * 60
    private static let cacheKey = "weather.desktop.snapshot"

    enum State {
        case loading
        case notFound
        case failed
        case ready(WeatherSnapshot, stale: Bool)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshFailed = false
    private var wakeObserver: AnyCancellable?
    private let defaults: UserDefaults
    private let session: URLSession
    private var requestID = UUID()
    private var requestCity: String?

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        wakeObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.refresh(force: true) }
            }
    }

    func refresh(force: Bool = false) async {
        let city = (defaults.string(forKey: "weather.city") ?? "Kathmandu")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A periodic tick must not supersede the forced request started on wake.
        if !force, isRefreshing, requestCity == city { return }
        let id = UUID()
        requestID = id
        requestCity = city
        isRefreshing = false
        guard !city.isEmpty else {
            state = .notFound
            return
        }

        // Never display another city's cached weather after the setting changes.
        let cached = defaults.data(forKey: Self.cacheKey)
            .flatMap { try? JSONDecoder().decode(WeatherSnapshot.self, from: $0) }
        let old = cached?.city == city ? cached : nil
        if !force, !refreshFailed, let old, !old.isStale() {
            state = .ready(old, stale: false)
            return
        }

        if let old { state = .ready(old, stale: old.isStale() || refreshFailed) }
        else { state = .loading }
        isRefreshing = true
        defer { if requestID == id { isRefreshing = false } }
        do {
            let locations: GeocodingResponse = try await fetch(
                "https://geocoding-api.open-meteo.com/v1/search",
                query: [URLQueryItem(name: "name", value: city),
                        URLQueryItem(name: "count", value: "1"),
                        URLQueryItem(name: "language", value: "en")])
            guard requestID == id, !Task.isCancelled else { return }
            guard let location = locations.results?.first else {
                state = .notFound
                return
            }

            let forecast: ForecastResponse = try await fetch(
                "https://api.open-meteo.com/v1/forecast",
                query: [URLQueryItem(name: "latitude", value: String(location.latitude)),
                        URLQueryItem(name: "longitude", value: String(location.longitude)),
                        URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
                        URLQueryItem(name: "temperature_unit", value: "celsius"),
                        URLQueryItem(name: "timeformat", value: "unixtime")])
            guard requestID == id, !Task.isCancelled else { return }
            let snapshot = WeatherSnapshot(city: city, place: location.name,
                                           tempC: forecast.current.temperature_2m,
                                           code: forecast.current.weather_code,
                                           isDay: forecast.current.is_day == 1,
                                           fetchedAt: Date(),
                                           observedAt: Date(timeIntervalSince1970: forecast.current.time))
            defaults.set(try? JSONEncoder().encode(snapshot), forKey: Self.cacheKey)
            refreshFailed = false
            state = .ready(snapshot, stale: snapshot.isStale())
        } catch {
            // A cancelled or superseded request must not overwrite the current city.
            guard requestID == id, !Task.isCancelled else { return }
            refreshFailed = true
            if let old {
                state = .ready(old, stale: true)
            } else {
                state = .failed
            }
        }
    }

    private func fetch<T: Decodable>(_ endpoint: String, query: [URLQueryItem]) async throws -> T {
        guard var components = URLComponents(string: endpoint) else { throw URLError(.badURL) }
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private struct GeocodingResponse: Decodable {
        struct Location: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
        }
        let results: [Location]?
    }

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let time: Double
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }
}
