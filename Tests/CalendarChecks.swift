import Foundation

@main
struct CalendarChecks {
    static func main() {
        let calendar = NepaliCalendar.gregorian(in: NepaliCalendar.timeZone)
        func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        func check(_ ad: Date, _ year: Int, _ month: Int, _ day: Int) {
            precondition(NepaliCalendar.date(from: ad) == NepaliDate(year: year, month: month, day: day),
                         "Unexpected conversion for \(ad)")
        }

        // Published conversion examples and independently checked modern calendar boundaries.
        check(date(1943, 4, 14), 2000, 1, 1)
        check(date(1944, 5, 28), 2001, 2, 15)
        check(date(1994, 8, 13), 2051, 4, 29)
        check(date(2023, 1, 28), 2079, 10, 14)
        check(date(2023, 2, 7), 2079, 10, 24)
        check(date(2024, 4, 12), 2080, 12, 30)
        check(date(2024, 4, 13), 2081, 1, 1)
        check(date(2025, 4, 14), 2082, 1, 1)
        check(date(2026, 4, 14), 2083, 1, 1)
        check(date(2026, 10, 15), 2083, 6, 29)
        check(date(2026, 10, 17), 2083, 6, 31)
        check(date(2026, 10, 18), 2083, 7, 1)
        check(date(2043, 4, 13), 2099, 12, 30)
        precondition(NepaliCalendar.date(from: date(1943, 4, 13)) == nil)
        precondition(NepaliCalendar.date(from: date(2043, 4, 14)) == nil)

        // Nepal midnight falls on the previous UTC day; both labels must roll over together.
        let iso = ISO8601DateFormatter()
        let before = iso.date(from: "2026-10-17T18:14:59Z")!
        let after = before.addingTimeInterval(1)
        check(before, 2083, 6, 31)
        check(after, 2083, 7, 1)
        precondition(NepaliCalendar.nextMidnight(after: before, mode: .both) == after)
        let text = CalendarDateText(date: after, mode: .both)
        precondition(text.englishDay == "18" && text.weekday == "SUN")
        precondition(text.nepali?.dayText == "१" && text.nepali?.monthAndYear == "कात्तिक २०८३")
        precondition(NepaliDate.numerals(2083) == "२०८३")

        // Exercise every supported day, including 29–32-day months and Gregorian leap days.
        // Local date arithmetic catches errors around the 1986 Nepal time-zone transition.
        var current = date(1943, 4, 14)
        var count = 0
        for (yearIndex, months) in BikramSambatData.months.enumerated() {
            precondition(months.count == 12 && months.allSatisfy { (29...32).contains($0) })
            for (monthIndex, days) in months.enumerated() {
                for day in 1...days {
                    check(current, 2000 + yearIndex, monthIndex + 1, day)
                    current = calendar.date(byAdding: .day, value: 1, to: current)!
                    count += 1
                }
            }
        }
        precondition(current == date(2043, 4, 14))
        print("Calendar checks passed: \(count) days, reference dates, boundaries, formatting, and Nepal midnight.")
    }
}
