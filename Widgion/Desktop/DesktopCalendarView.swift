import SwiftUI

// Uses the same offline date conversion and card layout as the system widget.
struct DesktopCalendarView: View {
    @AppStorage("calendar.display") private var display = CalendarDisplayMode.both
    @AppStorage("calendar.size") private var size = WidgetSize.small
    @AppStorage("calendar.accent") private var accentPreset = AccentPreset.standard.rawValue
    @AppStorage("calendar.hex") private var accentHex = ""

    // The weekday is the accent; its default is red.
    private var accent: Color {
        Accent.resolve(preset: accentPreset, hex: accentHex,
                       fallback: Color(red: 1.0, green: 0.27, blue: 0.23))
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            CalendarCardView(date: context.date, mode: display, wide: size == .wide,
                             accent: accent, secondary: Ink.secondary)
        }
    }
}
