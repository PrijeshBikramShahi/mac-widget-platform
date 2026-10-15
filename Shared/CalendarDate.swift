import Foundation

enum CalendarDisplayMode: String, CaseIterable, Identifiable {
    case both, nepali, english
    var id: String { rawValue }
    var label: String {
        switch self {
        case .both: return "English + Nepali"
        case .nepali: return "Nepali (BS)"
        case .english: return "English (AD)"
        }
    }
}

struct NepaliDate: Equatable {
    let year: Int
    let month: Int
    let day: Int

    var monthName: String {
        ["बैशाख", "जेठ", "असार", "साउन", "भदौ", "असोज",
         "कात्तिक", "मंसिर", "पुस", "माघ", "फागुन", "चैत"][month - 1]
    }
    var dayText: String { Self.numerals(day) }
    var monthAndYear: String { "\(monthName) \(Self.numerals(year))" }
    var fullText: String { "\(dayText) \(monthAndYear) बि.सं." }

    static func numerals(_ number: Int) -> String {
        let digits = Array("०१२३४५६७८९")
        return String(String(number).map { character in
            character.wholeNumberValue.map { digits[$0] } ?? character
        })
    }
}

enum NepaliCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Kathmandu")!

    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static let calendar = gregorian(in: timeZone)
    // Count civil days in Nepal, rather than dividing elapsed seconds by 86,400.
    // This also handles Nepal's historical UTC offset change correctly.
    private static let reference = calendar.date(from: DateComponents(year: 1943, month: 4, day: 14))!

    static func date(from date: Date) -> NepaliDate? {
        guard date.timeIntervalSinceReferenceDate.isFinite,
              var remaining = calendar.dateComponents([.day], from: reference,
                                                       to: calendar.startOfDay(for: date)).day,
              remaining >= 0 else { return nil }
        for (yearIndex, months) in BikramSambatData.months.enumerated() {
            let yearDays = months.reduce(0, +)
            if remaining >= yearDays {
                remaining -= yearDays
                continue
            }
            for (monthIndex, days) in months.enumerated() {
                if remaining < days {
                    return NepaliDate(year: BikramSambatData.firstYear + yearIndex,
                                      month: monthIndex + 1, day: remaining + 1)
                }
                remaining -= days
            }
        }
        return nil // Never invent a date outside the bundled calendar table.
    }

    static func nextMidnight(after date: Date, mode: CalendarDisplayMode) -> Date {
        let calendar = gregorian(in: mode == .english ? .current : timeZone)
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
}

/// Both labels always describe the same civil day. Nepali/combined mode uses Nepal time.
struct CalendarDateText {
    let nepali: NepaliDate?
    let weekday: String
    let nepaliWeekday: String
    let englishDay: String
    let englishMonth: String
    let englishMonthAndYear: String
    let englishShortDate: String
    let englishFullDate: String

    init(date: Date, mode: CalendarDisplayMode) {
        let zone = mode == .english ? TimeZone.current : NepaliCalendar.timeZone
        let calendar = NepaliCalendar.gregorian(in: zone)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = zone
        func format(_ pattern: String) -> String {
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
        nepali = NepaliCalendar.date(from: date)
        weekday = format("EEE").uppercased()
        nepaliWeekday = ["आइतबार", "सोमबार", "मंगलबार", "बुधबार", "बिहीबार", "शुक्रबार", "शनिबार"][calendar.component(.weekday, from: date) - 1]
        englishDay = format("d")
        englishMonth = format("MMMM")
        englishMonthAndYear = format("MMM yyyy")
        englishShortDate = format("d MMM")
        englishFullDate = format("EEEE, d MMMM yyyy")
    }
}
