import Foundation

// MARK: - Holiday entry

/// One official Chinese public holiday period.
///
/// Dates are Beijing (UTC+8) calendar days, inclusive, exactly as published in the
/// annual notice of the General Office of the State Council. DeepSeek excludes these
/// days from peak pricing in full: "Peak hours are 01:00 - 04:00 and 06:00 - 10:00 UTC,
/// Monday through Friday, excluding Chinese public holidays. All other hours are
/// off-peak, including weekends and Chinese public holidays in full."
///
/// Adjusted working days (调休) are deliberately ignored: DeepSeek bills weekends as
/// off-peak regardless, so a weekend working day is never peak.
public struct ChineseHoliday: Codable, Hashable, Sendable {
    /// Published name, e.g. "National Day".
    public var name: String
    /// First day, "yyyy-MM-dd" in Beijing time.
    public var start: String
    /// Last day (inclusive), "yyyy-MM-dd" in Beijing time.
    public var end: String

    public init(name: String, start: String, end: String) {
        self.name = name
        self.start = start
        self.end = end
    }
}

// MARK: - Calendar

/// Chinese public holiday dates used to suspend peak windows.
///
/// The bundled data covers the years published by the State Council so far. When a
/// year is missing, the app says so instead of silently guessing: DeepSeek publishes
/// the exclusions, and this project does not invent them.
public struct HolidayCalendar: Codable, Hashable, Sendable {

    /// Source note shown to users (who published the dates).
    public var source: String?
    /// Holiday periods keyed by Beijing year, e.g. "2026".
    public var years: [String: [ChineseHoliday]]

    public init(source: String? = nil, years: [String: [ChineseHoliday]]) {
        self.source = source
        self.years = years
    }

    /// China Standard Time. Fixed at UTC+8 since 1991; the identifier is used so the
    /// calendar always matches the published dates.
    public static let beijing: TimeZone =
        TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!

    private static var calendar: Calendar { DeepSeekClock.calendar(in: beijing) }

    // MARK: Day helpers

    /// "yyyy-MM-dd" of the Beijing day containing `date`.
    public static func beijingDay(of date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func dayStart(_ day: String) -> Date? {
        let parts = day.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Beijing year containing `date`.
    public static func beijingYear(of date: Date) -> Int {
        calendar.component(.year, from: date)
    }

    // MARK: Lookup

    public var coveredYears: Set<Int> {
        Set(years.keys.compactMap { Int($0) })
    }

    public func hasData(forYear year: Int) -> Bool {
        !(years[String(year)] ?? []).isEmpty
    }

    public func entries(forYear year: Int) -> [ChineseHoliday] {
        (years[String(year)] ?? []).sorted { $0.start < $1.start }
    }

    /// Holiday period covering the Beijing day that contains `date`, if any.
    public func holiday(onBeijingDayContaining date: Date) -> ChineseHoliday? {
        let day = Self.beijingDay(of: date)
        return entries(forYear: Self.beijingYear(of: date)).first { day >= $0.start && day <= $0.end }
    }

    /// Full `DateInterval` of a holiday period (Beijing midnight to midnight).
    public func interval(for holiday: ChineseHoliday) -> DateInterval? {
        guard let start = Self.dayStart(holiday.start) else { return nil }
        let lastDay = Self.dayStart(holiday.end) ?? start
        guard let end = Self.calendar.date(byAdding: .day, value: 1, to: lastDay), end > start else {
            return DateInterval(start: start, end: start.addingTimeInterval(86_400))
        }
        return DateInterval(start: start, end: end)
    }

    /// Holiday periods overlapping [from, to), clipped to that range.
    public func holidayIntervals(from: Date, to: Date) -> [DateInterval] {
        guard to > from else { return [] }
        let bounds = DateInterval(start: from, end: to)
        var result: [DateInterval] = []
        let firstYear = Self.beijingYear(of: from)
        let lastYear = Self.beijingYear(of: to)
        guard lastYear >= firstYear, lastYear - firstYear <= 5 else { return [] }
        for year in firstYear...lastYear {
            for holiday in entries(forYear: year) {
                guard let interval = interval(for: holiday),
                      let clipped = interval.intersection(with: bounds) else { continue }
                result.append(clipped)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    /// First Beijing year in [from, to] whose holiday dates are not known yet.
    public func firstYearWithoutData(from: Date, to: Date) -> Int? {
        guard to >= from else { return nil }
        let firstYear = Self.beijingYear(of: from)
        let lastYear = Self.beijingYear(of: to)
        guard lastYear >= firstYear, lastYear - firstYear <= 5 else { return nil }
        for year in firstYear...lastYear where !hasData(forYear: year) {
            return year
        }
        return nil
    }

    /// Overlays `other` on top of this calendar. A year defined by `other` replaces
    /// the bundled year entirely, so a user file can both add and remove dates.
    public func merging(_ other: HolidayCalendar) -> HolidayCalendar {
        var merged = years
        for (year, entries) in other.years where !entries.isEmpty {
            merged[year] = entries
        }
        return HolidayCalendar(source: other.source ?? source, years: merged)
    }

    // MARK: Official data

    /// Dates published by the General Office of the State Council of the PRC.
    ///
    /// 2025: notice of 12 November 2024.
    /// 2026: notice of 4 November 2025.
    /// The notice for 2027 had not been published when this build was made; add it to
    /// holidays.json (menu > Edit holiday dates) as soon as it appears.
    public static let official = HolidayCalendar(
        source: "General Office of the State Council of the PRC (2025-2026 notices)",
        years: [
            "2025": [
                ChineseHoliday(name: "New Year's Day", start: "2025-01-01", end: "2025-01-01"),
                ChineseHoliday(name: "Spring Festival", start: "2025-01-28", end: "2025-02-04"),
                ChineseHoliday(name: "Qingming Festival", start: "2025-04-04", end: "2025-04-06"),
                ChineseHoliday(name: "Labour Day", start: "2025-05-01", end: "2025-05-05"),
                ChineseHoliday(name: "Dragon Boat Festival", start: "2025-05-31", end: "2025-06-02"),
                ChineseHoliday(name: "National Day & Mid-Autumn Festival", start: "2025-10-01", end: "2025-10-08")
            ],
            "2026": [
                ChineseHoliday(name: "New Year's Day", start: "2026-01-01", end: "2026-01-03"),
                ChineseHoliday(name: "Spring Festival", start: "2026-02-15", end: "2026-02-23"),
                ChineseHoliday(name: "Qingming Festival", start: "2026-04-04", end: "2026-04-06"),
                ChineseHoliday(name: "Labour Day", start: "2026-05-01", end: "2026-05-05"),
                ChineseHoliday(name: "Dragon Boat Festival", start: "2026-06-19", end: "2026-06-21"),
                ChineseHoliday(name: "Mid-Autumn Festival", start: "2026-09-25", end: "2026-09-27"),
                ChineseHoliday(name: "National Day", start: "2026-10-01", end: "2026-10-07")
            ]
        ]
    )
}
