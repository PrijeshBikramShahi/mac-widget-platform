import SwiftUI
import WidgetKit

/// Shared by the desktop card and WidgetKit so date formatting stays consistent.
struct CalendarCardView: View {
    let date: Date
    let mode: CalendarDisplayMode
    let wide: Bool
    var expanded = false
    var accent: Color = .red
    var secondary: Color = .secondary

    var body: some View {
        let text = CalendarDateText(date: date, mode: mode)
        VStack(spacing: expanded ? 4 : 0) {
            Text(mode == .nepali ? text.nepaliWeekday : text.weekday)
                .font(.system(size: expanded ? 13 : 10, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .widgetAccentable()

            if mode == .both, wide, let nepali = text.nepali {
                HStack(spacing: expanded ? 20 : 10) {
                    dateColumn(day: nepali.dayText, month: nepali.monthAndYear, era: "BS")
                    Rectangle().fill(secondary.opacity(0.25)).frame(width: 1, height: expanded ? 65 : 40)
                        .accessibilityHidden(true)
                    dateColumn(day: text.englishDay, month: text.englishMonthAndYear, era: "AD")
                }
            } else if mode != .english, let nepali = text.nepali {
                Text(nepali.dayText)
                    .font(.system(size: expanded ? 48 : 32, weight: .semibold, design: .rounded))
                Text(nepali.monthAndYear)
                    .font(.system(size: expanded ? 14 : 11, weight: .medium))
                    .foregroundStyle(secondary)
                if mode == .both {
                    Text("\(text.englishShortDate) AD")
                        .font(.system(size: expanded ? 12 : 10, weight: .medium, design: .rounded))
                        .foregroundStyle(secondary)
                        .padding(.top, expanded ? 4 : 1)
                } else {
                    Text("बि.सं.")
                        .font(.system(size: expanded ? 12 : 10, weight: .medium))
                        .foregroundStyle(secondary)
                }
            } else {
                Text(text.englishDay)
                    .font(.system(size: expanded ? 56 : 40, weight: .semibold, design: .rounded))
                Text(expanded ? text.englishMonthAndYear : text.englishMonth)
                    .font(.system(size: expanded ? 15 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(secondary)
                if mode != .english {
                    Text("BS unavailable")
                        .font(.system(size: expanded ? 12 : 9))
                        .foregroundStyle(secondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, expanded ? 0 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(text))
    }

    private func dateColumn(day: String, month: String, era: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(day)
                    .font(.system(size: expanded ? 48 : 32, weight: .semibold, design: .rounded))
                Text(era)
                    .font(.system(size: expanded ? 10 : 8, weight: .bold, design: .rounded))
                    .foregroundStyle(secondary)
            }
            Text(month)
                .font(.system(size: expanded ? 13 : 11, weight: .medium))
                .foregroundStyle(secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func accessibilityText(_ text: CalendarDateText) -> String {
        switch mode {
        case .english: return text.englishFullDate
        case .nepali:
            return text.nepali.map { "\(text.nepaliWeekday), \($0.fullText), Nepal time" }
                ?? "\(text.englishFullDate), Nepali date unavailable"
        case .both:
            return "\(text.nepali?.fullText ?? "Nepali date unavailable"), \(text.englishFullDate) AD, Nepal time"
        }
    }
}
