import SwiftUI
import AppKit

struct DesktopWeatherView: View {
    @ObservedObject var service = WeatherService.shared
    @AppStorage("weather.size") private var size = WidgetSize.wide
    @AppStorage("weather.city") private var city = "Kathmandu"
    @AppStorage("weather.units") private var units = TempUnit.celsius
    @AppStorage("weather.accent") private var accentPreset = AccentPreset.standard.rawValue
    @AppStorage("weather.hex") private var accentHex = ""

    private var accent: Color { Accent.resolve(preset: accentPreset, hex: accentHex, fallback: .white) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(at: context.date)
        }
            .contextMenu {
                Button("Refresh weather", systemImage: "arrow.clockwise") {
                    Task { await service.refresh(force: true) }
                }
                .disabled(service.isRefreshing)
            }
            .padding(size == .small ? 10 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: city) {
                repeat {
                    await service.refresh()
                    do {
                        try await Task.sleep(for: .seconds(60))
                    } catch {
                        return
                    }
                } while !Task.isCancelled
            }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        switch service.state {
        case .loading:
            message("cloud", "Loading…")
        case .notFound:
            message("mappin.slash", "City not found")
        case .failed:
            message("wifi.slash", "No weather data")
        case .ready(let s, let stale):
            ready(s, stale: stale || s.isStale(at: date))
                .help(details(s, stale: stale || s.isStale(at: date)))
        }
    }

    private func details(_ snapshot: WeatherSnapshot, stale: Bool) -> String {
        let time = (snapshot.observedAt ?? snapshot.fetchedAt).formatted(date: .abbreviated, time: .shortened)
        let status = stale ? "Old data — last available conditions" : "Current conditions"
        let refresh = service.isRefreshing ? " Refreshing…" : (service.refreshFailed ? " Refresh failed; showing saved weather." : "")
        return "\(status) for \(snapshot.place), \(time). Open-Meteo.\(refresh)"
    }

    private func message(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 20))
            Text(text).font(.system(size: 11, weight: .medium, design: .rounded))
            Text("Open-Meteo.com").font(.system(size: 7)).foregroundStyle(Ink.tertiary)
        }
        .foregroundStyle(Ink.secondary)
    }

    private func temperature(_ c: Double) -> String {
        let v = units == .fahrenheit ? c * 9 / 5 + 32 : c
        return "\(Int(v.rounded()))°"
    }

    @ViewBuilder
    private func ready(_ s: WeatherSnapshot, stale: Bool) -> some View {
        let info = WeatherInfo.describe(code: s.code, isDay: s.isDay)
        let credit = "Open-Meteo.com"
        let status = stale ? "Old data" : "Current"
        let time = (s.observedAt ?? s.fetchedAt).formatted(date: .omitted, time: .shortened)

        if size == .small {
            // Small: condition stays under the temperature (no room beside the icon).
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(s.place)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 2)
                    Image(systemName: info.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14))
                }
                Spacer(minLength: 0)
                Text(temperature(s.tempC))
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(info.label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text("\(status) · \(time)")
                    .font(.system(size: 7, weight: stale ? .semibold : .regular))
                    .foregroundStyle(stale ? .yellow : Ink.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(credit)
                    .font(.system(size: 6))
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        } else {
            // The footer spans both columns, leaving the condition centered under its icon.
            VStack(spacing: 3) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(accent)
                                .accessibilityHidden(true)
                            Text(s.place)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                        Text(temperature(s.tempC))
                            .font(.system(size: 33, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 4) {
                        Image(systemName: info.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 26))
                            .frame(height: 29)
                        Text(info.label)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: 70)
                }
                .frame(maxHeight: .infinity)
                Text("\(status) · \(time) · \(credit)")
                    .font(.system(size: 7, weight: stale ? .semibold : .regular))
                    .foregroundStyle(stale ? .yellow : Ink.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
