import WidgetKit
import SwiftUI

// Phase 1 clock prototype: digital + analog, hours and minutes only.
// Question being tested: does WidgetKit honor one timeline entry per minute
// on the macOS desktop, and how far behind the menu bar clock does it run?

// Flip to test both formats.
private let use24Hour = true

struct ClockEntry: TimelineEntry {
    let date: Date
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let start = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let entries = (0..<60).map { ClockEntry(date: start.addingTimeInterval(Double($0) * 60)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DigitalClock: View {
    let date: Date

    private var text: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return f.string(from: date)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 44, weight: .semibold, design: .rounded))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

struct AnalogClock: View {
    let date: Date

    var body: some View {
        let cal = Calendar.current
        let minute = Double(cal.component(.minute, from: date))
        let hour = Double(cal.component(.hour, from: date) % 12)
        let minuteAngle = minute * 6
        let hourAngle = hour * 30 + minute * 0.5

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().stroke(.secondary, lineWidth: 2)
                Capsule().fill(.primary)
                    .frame(width: 4, height: size * 0.25)
                    .offset(y: -size * 0.125)
                    .rotationEffect(.degrees(hourAngle))
                Capsule().fill(.primary)
                    .frame(width: 3, height: size * 0.38)
                    .offset(y: -size * 0.19)
                    .rotationEffect(.degrees(minuteAngle))
                Circle().fill(.primary).frame(width: 8, height: 8)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

struct ClockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClockEntry

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                DigitalClock(date: entry.date)
                AnalogClock(date: entry.date)
            }
        default:
            DigitalClock(date: entry.date)
        }
    }
}


struct ClockPrototypeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClockPrototype", provider: ClockProvider()) { entry in
            ClockView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Clock Prototype")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
