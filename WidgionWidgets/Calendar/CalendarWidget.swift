import WidgetKit
import SwiftUI

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
