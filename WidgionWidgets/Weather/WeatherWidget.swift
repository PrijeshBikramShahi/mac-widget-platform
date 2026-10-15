import WidgetKit
import SwiftUI

// MARK: - Weather (Open-Meteo, cached, at most one call per 30 minutes)

struct CachedWeather: Codable {
    let tempC: Double
    let code: Int
    let isDay: Bool
    let fetchedAt: Date
    var observedAt: Date? = nil

    func isStale(at date: Date) -> Bool {
        guard let observedAt else { return true }
        return date.timeIntervalSince(observedAt) >= WeatherRepo.maxAge
            || date.timeIntervalSince(fetchedAt) >= WeatherRepo.maxAge
    }
}

enum WeatherRepo {
    static let key = "cachedWeather"
    static let maxAge: TimeInterval = 30 * 60

    static func cached() -> CachedWeather? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedWeather.self, from: data)
    }

    static func load() async -> CachedWeather? {
        let old = cached()
        if let old, !old.isStale(at: .now) { return old }

        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(WidgionConfig.weatherLat)),
            URLQueryItem(name: "longitude", value: String(WidgionConfig.weatherLon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
        ]
        guard let url = comps.url else { return old }

        struct Response: Decodable {
            struct Current: Decodable {
                let time: Double
                let temperature_2m: Double
                let weather_code: Int
                let is_day: Int
            }
            let current: Current
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return old }
            let r = try JSONDecoder().decode(Response.self, from: data)
            let fresh = CachedWeather(tempC: r.current.temperature_2m,
                                      code: r.current.weather_code,
                                      isDay: r.current.is_day == 1,
                                      fetchedAt: Date(),
                                      observedAt: Date(timeIntervalSince1970: r.current.time))
            UserDefaults.standard.set(try? JSONEncoder().encode(fresh), forKey: key)
            return fresh
        } catch {
            return old   // keep showing the last data, with its age
        }
    }
}

func describe(code: Int, isDay: Bool) -> (label: String, symbol: String) {
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

struct WeatherEntry: TimelineEntry {
    let date: Date
    let weather: CachedWeather?
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, weather: CachedWeather(tempC: 22, code: 1, isDay: true, fetchedAt: .now, observedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let w = await WeatherRepo.load()
            let now = Date()
            let expiry = min(w?.observedAt ?? now, w?.fetchedAt ?? now).addingTimeInterval(WeatherRepo.maxAge)
            let next = max(now.addingTimeInterval(60), expiry)
            var entries = [WeatherEntry(date: now, weather: w)]
            if expiry > now { entries.append(WeatherEntry(date: expiry, weather: w)) }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }
}

struct WeatherView: View {
    let entry: WeatherEntry

    var body: some View {
        if let w = entry.weather {
            let info = describe(code: w.code, isDay: w.isDay)
            HStack(spacing: 14) {
                Image(systemName: info.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 48))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(WidgionConfig.weatherPlace)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(Int(w.tempC.rounded()))°")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                    Text(info.label)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    Text("\(w.isStale(at: entry.date) ? "Old data" : "Current") · \((w.observedAt ?? w.fetchedAt).formatted(date: .omitted, time: .shortened)) · Open-Meteo.com")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "wifi.slash").font(.title2)
                Text("No weather data").font(.system(size: 13, weight: .medium, design: .rounded))
                Text("Open-Meteo.com").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
        }
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeatherWidget", provider: WeatherProvider()) { entry in
            WeatherView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weather")
        .supportedFamilies([.systemMedium])
    }
}
