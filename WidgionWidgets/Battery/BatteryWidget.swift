import WidgetKit
import SwiftUI
import IOKit.ps

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
                if WidgionConfig.batteryStyle != .percent {
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: Double(p) / 100)
                            .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .widgetAccentable()
                        if WidgionConfig.batteryStyle == .both {
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
