import WidgetKit
import SwiftUI
import IOKit.ps

// Calendar, Weather and Battery widgets (first pass), plus the widget bundle.
// Before building: remove the `@main` line from ClockPrototype.swift.
// The widget target needs App Sandbox + "Outgoing Connections (Client)" for weather.

// MARK: - Settings you can edit
 
private let weatherPlace = "Kathmandu"
private let weatherLat = 27.7172
private let weatherLon = 85.3240

enum BatteryStyle { case ring, percent, both }
private let batteryStyle = BatteryStyle.both

// MARK: - Calendar

struct DateEntry: TimelineEntry {
    let date: Date
}

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> DateEntry { DateEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (DateEntry) -> Void) {
        completion(DateEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DateEntry>) -> Void) {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: .now) ?? .now
        let midnight = cal.startOfDay(for: tomorrow)
        completion(Timeline(entries: [DateEntry(date: .now), DateEntry(date: midnight)], policy: .atEnd))
    }
}

struct CalendarView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DateEntry

    var body: some View {
        let d = entry.date
        VStack(alignment: .leading, spacing: 2) {
            Text(d.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.red)
                .widgetAccentable()
            Text(d.formatted(.dateTime.day()))
                .font(.system(size: family == .systemSmall ? 56 : 64, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
            Text(d.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalendarWidget", provider: CalendarProvider()) { entry in
            CalendarView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Calendar")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Weather (Open-Meteo, cached, at most one call per 30 minutes)

struct CachedWeather: Codable {
    let tempC: Double
    let code: Int
    let isDay: Bool
    let fetchedAt: Date
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
        if let old, Date().timeIntervalSince(old.fetchedAt) < maxAge { return old }

        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(weatherLat)),
            URLQueryItem(name: "longitude", value: String(weatherLon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = comps.url else { return old }

        struct Response: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double
                let weather_code: Int
                let is_day: Int
            }
            let current: Current
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let r = try JSONDecoder().decode(Response.self, from: data)
            let fresh = CachedWeather(tempC: r.current.temperature_2m,
                                      code: r.current.weather_code,
                                      isDay: r.current.is_day == 1,
                                      fetchedAt: Date())
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
    case 1, 2: return ("Partly cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
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
        WeatherEntry(date: .now, weather: CachedWeather(tempC: 22, code: 1, isDay: true, fetchedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let w = await WeatherRepo.load()
            let next = Date().addingTimeInterval(WeatherRepo.maxAge)
            completion(Timeline(entries: [WeatherEntry(date: .now, weather: w)], policy: .after(next)))
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
                    Text(weatherPlace)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(Int(w.tempC.rounded()))°")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                    Text(info.label)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)
                    Text("Open-Meteo.com · updated \(w.fetchedAt.formatted(date: .omitted, time: .shortened))")
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

// MARK: - Battery (MacBook only for now; Bluetooth comes in its own prototype)

func readMacBattery() -> (percent: Int, charging: Bool)? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
    for source in list {
        guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              let current = d[kIOPSCurrentCapacityKey] as? Int,
              let maxCap = d[kIOPSMaxCapacityKey] as? Int, maxCap > 0 else { continue }
        let charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
        return (current * 100 / maxCap, charging)
    }
    return nil
}

struct BatteryEntry: TimelineEntry {
    let date: Date
    let percent: Int?
    let charging: Bool
}

struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: .now, percent: 80, charging: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func current() -> BatteryEntry {
        let b = readMacBattery()
        return BatteryEntry(date: .now, percent: b?.percent, charging: b?.charging ?? false)
    }
}

struct BatteryView: View {
    let entry: BatteryEntry

    var body: some View {
        if let p = entry.percent {
            let color: Color = (p <= 20 && !entry.charging) ? .red : .green
            VStack(spacing: 6) {
                if batteryStyle != .percent {
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: Double(p) / 100)
                            .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .widgetAccentable()
                        if batteryStyle == .both {
                            Text("\(p)%")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        } else if entry.charging {
                            Image(systemName: "bolt.fill").foregroundStyle(color)
                        }
                    }
                    .padding(6)
                } else {
                    Text("\(p)%")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                }
                HStack(spacing: 3) {
                    if entry.charging { Image(systemName: "bolt.fill").font(.caption2) }
                    Text("MacBook")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("No battery")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BatteryWidget", provider: BatteryProvider()) { entry in
            BatteryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Battery")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct CWTestWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClockPrototypeWidget()
        CalendarWidget()
        WeatherWidget()
        BatteryWidget()
    }
}
