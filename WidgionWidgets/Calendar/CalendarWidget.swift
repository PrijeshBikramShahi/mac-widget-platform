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
        let now = Date.now
        let midnight = NepaliCalendar.nextMidnight(after: now, mode: .both)
        completion(Timeline(entries: [DateEntry(date: now), DateEntry(date: midnight)], policy: .atEnd))
    }
}

struct CalendarView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DateEntry

    var body: some View {
        CalendarCardView(date: entry.date, mode: .both, wide: family == .systemMedium,
                         expanded: true)
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalendarWidget", provider: CalendarProvider()) { entry in
            CalendarView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("English + Nepali Calendar")
        .description("Today in Bikram Sambat and Gregorian dates, using Nepal time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
