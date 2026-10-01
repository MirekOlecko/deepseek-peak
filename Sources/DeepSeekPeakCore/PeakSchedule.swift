import Foundation

// MARK: - Peak rule

/// A single peak window described in UTC.
public struct PeakRule: Codable, Hashable, Sendable {
    /// Weekdays using the Gregorian calendar: 1 = Sunday, 2 = Monday ... 7 = Saturday.
    public var weekdays: Set<Int>
    /// Window start as minutes from UTC midnight (e.g. 60 = 01:00).
    public var startMinuteUTC: Int
    /// Window end as minutes from UTC midnight. A value <= startMinuteUTC means the window crosses midnight.
    public var endMinuteUTC: Int

    public init(weekdays: Set<Int>, startMinuteUTC: Int, endMinuteUTC: Int) {
        self.weekdays = weekdays
        self.startMinuteUTC = startMinuteUTC
        self.endMinuteUTC = endMinuteUTC
    }

    public init(weekdays: Set<Int>, from: (Int, Int), to: (Int, Int)) {
        self.init(weekdays: weekdays,
                  startMinuteUTC: from.0 * 60 + from.1,
                  endMinuteUTC: to.0 * 60 + to.1)
    }

    /// Window length in seconds.
    public var duration: TimeInterval {
        var minutes = endMinuteUTC - startMinuteUTC
        if minutes <= 0 { minutes += 24 * 60 }
        return TimeInterval(minutes * 60)
    }

    public var spanLabelUTC: String {
        String(format: "%02d:%02d-%02d:%02d",
               startMinuteUTC / 60, startMinuteUTC % 60,
               endMinuteUTC / 60, endMinuteUTC % 60)
    }
}

// MARK: - Schedule

/// A set of peak rules. Defaults to the official DeepSeek API price list.
public struct PeakSchedule: Codable, Hashable, Sendable {
    public var rules: [PeakRule]
    public var note: String?
    /// When true, peak windows that fall on an official Chinese public holiday are
    /// billed as off-peak, exactly as DeepSeek's price list states.
    public var excludeChineseHolidays: Bool
    /// Holiday dates used by `excludeChineseHolidays`. Never written to schedule.json:
    /// it has its own file and its own yearly update cycle.
    public var holidays: HolidayCalendar

    public init(rules: [PeakRule],
                note: String? = nil,
                excludeChineseHolidays: Bool = true,
                holidays: HolidayCalendar = .official) {
        self.rules = rules
        self.note = note
        self.excludeChineseHolidays = excludeChineseHolidays
        self.holidays = holidays
    }

    private enum CodingKeys: String, CodingKey {
        case rules
        case note
        case excludeChineseHolidays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decode([PeakRule].self, forKey: .rules)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        // Schedules written before holiday support (or by hand) keep DeepSeek's rule.
        excludeChineseHolidays = try container.decodeIfPresent(Bool.self, forKey: .excludeChineseHolidays) ?? true
        holidays = .official
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rules, forKey: .rules)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(excludeChineseHolidays, forKey: .excludeChineseHolidays)
    }

    /// Monday through Friday.
    public static let weekdaysOnly: Set<Int> = [2, 3, 4, 5, 6]

    /// Official DeepSeek API schedule (checked 2026-10-01 at https://api-docs.deepseek.com/quick_start/pricing):
    /// "Peak hours are 01:00 - 04:00 and 06:00 - 10:00 UTC, Monday through Friday, excluding
    /// Chinese public holidays. All other hours are off-peak, including weekends and Chinese
    /// public holidays in full." Off-peak rates are half of the peak rates.
    public static let deepSeekDefault = PeakSchedule(
        rules: [
            PeakRule(weekdays: weekdaysOnly, from: (1, 0), to: (4, 0)),
            PeakRule(weekdays: weekdaysOnly, from: (6, 0), to: (10, 0))
        ],
        note: "Peak: 01:00-04:00 and 06:00-10:00 UTC, Mon-Fri, excluding Chinese public holidays. "
            + "Outside those windows rates are 50% lower."
    )

    public var isEmpty: Bool { rules.isEmpty }
}

// MARK: - Analysis result

public enum RatePeriod: String, Hashable, Sendable {
    case peak
    case offPeak
}

/// A contiguous stretch of time billed at a single rate.
public struct RateSegment: Hashable, Sendable {
    public let start: Date
    public let end: Date
    public let isPeak: Bool

    public init(start: Date, end: Date, isPeak: Bool) {
        self.start = start
        self.end = end
        self.isPeak = isPeak
    }

    public var interval: DateInterval { DateInterval(start: start, end: end) }
    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

/// The complete picture at a given moment.
public struct RateStatus: Hashable, Sendable {
    public let period: RatePeriod
    /// Start of the current same-rate window (the real start of a peak window).
    public let windowStart: Date
    /// End of the current window, i.e. the moment the rate changes.
    public let windowEnd: Date
    public let nextPeakStart: Date?
    public let nextPeakEnd: Date?
    /// Segments from "now" to the horizon, alternating peak / off-peak.
    public let timeline: [RateSegment]
    /// Chinese public holiday covering the current Beijing day, if any. Peak windows
    /// are suspended for the whole holiday.
    public let activeHoliday: ChineseHoliday?
    /// Set when the holiday dates for an upcoming Beijing year are not known yet, so
    /// the app can say that peak windows are only an assumption for that year.
    public let holidayDataMissingYear: Int?

    public var isPeak: Bool { period == .peak }
    /// True when the current off-peak stretch is a holiday, not a normal daily gap.
    public var isHolidaySuspended: Bool { !isPeak && activeHoliday != nil }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, windowEnd.timeIntervalSince(now))
    }

    public func elapsedFraction(at now: Date) -> Double {
        let total = windowEnd.timeIntervalSince(windowStart)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(windowStart) / total))
    }
}

// MARK: - Schedule engine

public enum DeepSeekClock {
    public static let utc = TimeZone(secondsFromGMT: 0)!

    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}

public extension PeakSchedule {

    /// All peak windows overlapping [from, to). Returned windows are not clipped,
    /// so the real start and end of each window is preserved.
    func peakIntervals(from: Date, to: Date) -> [DateInterval] {
        guard to > from, !rules.isEmpty else { return [] }
        let calendar = DeepSeekClock.utcCalendar
        var day = calendar.startOfDay(for: from.addingTimeInterval(-86_400))
        let limit = to.addingTimeInterval(86_400)
        var raw: [DateInterval] = []
        var iterations = 0

        while day <= limit, iterations < 1200 {
            iterations += 1
            let weekday = calendar.component(.weekday, from: day)
            for rule in rules where rule.weekdays.contains(weekday) {
                let start = day.addingTimeInterval(TimeInterval(rule.startMinuteUTC * 60))
                var end = day.addingTimeInterval(TimeInterval(rule.endMinuteUTC * 60))
                if rule.endMinuteUTC <= rule.startMinuteUTC {
                    end = end.addingTimeInterval(86_400)
                }
                if end > from, start < to {
                    raw.append(DateInterval(start: start, end: end))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        raw.sort { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in raw {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        // DeepSeek bills Chinese public holidays as off-peak in full.
        if excludeChineseHolidays, !holidays.coveredYears.isEmpty {
            let holidaysInRange = holidays.holidayIntervals(from: from.addingTimeInterval(-86_400),
                                                           to: to.addingTimeInterval(86_400))
            if !holidaysInRange.isEmpty {
                merged = Self.subtracting(holidaysInRange, from: merged)
            }
        }
        return merged
    }

    /// Removes `holes` from `intervals`, splitting an interval when a holiday falls inside it.
    private static func subtracting(_ holes: [DateInterval], from intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for interval in intervals {
            var pieces = [interval]
            for hole in holes where hole.intersects(interval) {
                var remaining: [DateInterval] = []
                for piece in pieces {
                    // Build both halves only when they are non-empty: NSDateInterval
                    // rejects an end that precedes its start.
                    let leftEnd = min(piece.end, hole.start)
                    if leftEnd > piece.start {
                        remaining.append(DateInterval(start: piece.start, end: leftEnd))
                    }
                    let rightStart = max(piece.start, hole.end)
                    if rightStart < piece.end {
                        remaining.append(DateInterval(start: rightStart, end: piece.end))
                    }
                }
                pieces = remaining
            }
            result.append(contentsOf: pieces)
        }
        return result.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
    }

    /// Peak/off-peak segments covering exactly [from, to].
    func segmented(from: Date, to: Date, peaks: [DateInterval]) -> [RateSegment] {
        guard to > from else { return [] }
        var result: [RateSegment] = []
        var cursor = from
        for peak in peaks {
            let start = max(peak.start, from)
            let end = min(peak.end, to)
            guard end > start else { continue }
            if start > cursor {
                result.append(RateSegment(start: cursor, end: start, isPeak: false))
            }
            result.append(RateSegment(start: start, end: end, isPeak: true))
            cursor = end
        }
        if cursor < to {
            result.append(RateSegment(start: cursor, end: to, isPeak: false))
        }
        return result
    }

    func segments(from: Date, to: Date) -> [RateSegment] {
        segmented(from: from, to: to, peaks: peakIntervals(from: from, to: to))
    }

    /// Current state: is peak running, when does the rate change, what does the next 24h look like.
    func status(at now: Date, horizon: TimeInterval = 86_400) -> RateStatus {
        let peaks = peakIntervals(from: now.addingTimeInterval(-8 * 86_400),
                                  to: now.addingTimeInterval(15 * 86_400))
        let timeline = segmented(from: now, to: now.addingTimeInterval(horizon), peaks: peaks)
        let holiday = excludeChineseHolidays ? holidays.holiday(onBeijingDayContaining: now) : nil
        // "Next peak" looks up to three weeks ahead, so an unpublished year matters as
        // soon as it starts inside that range.
        let missingYear = excludeChineseHolidays && !rules.isEmpty
            ? holidays.firstYearWithoutData(from: now, to: now.addingTimeInterval(21 * 86_400))
            : nil

        if let current = peaks.first(where: { $0.start <= now && now < $0.end }) {
            let following = peaks.first(where: { $0.start >= current.end })
            return RateStatus(period: .peak,
                              windowStart: current.start,
                              windowEnd: current.end,
                              nextPeakStart: following?.start,
                              nextPeakEnd: following?.end,
                              timeline: timeline,
                              activeHoliday: holiday,
                              holidayDataMissingYear: missingYear)
        }

        let next = peaks.first(where: { $0.start > now })
        let previous = peaks.last(where: { $0.end <= now })
        let windowEnd = next?.start ?? now.addingTimeInterval(horizon)
        let rawStart = previous?.end ?? windowEnd.addingTimeInterval(-6 * 3600)
        return RateStatus(period: .offPeak,
                          windowStart: min(rawStart, now),
                          windowEnd: windowEnd,
                          nextPeakStart: next?.start,
                          nextPeakEnd: next?.end,
                          timeline: timeline,
                          activeHoliday: holiday,
                          holidayDataMissingYear: missingYear)
    }

    /// True when the Beijing day containing `date` would carry peak windows if
    /// Chinese public holidays were not excluded, i.e. a peak day that a holiday
    /// suspends. Used to explain a skipped peak instead of staying silent.
    func wouldBePeakDayWithoutHolidays(on date: Date) -> Bool {
        guard excludeChineseHolidays, holidays.holiday(onBeijingDayContaining: date) != nil else {
            return false
        }
        var raw = self
        raw.excludeChineseHolidays = false
        let calendar = DeepSeekClock.calendar(in: HolidayCalendar.beijing)
        guard let dayStart = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: date)),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        return !raw.peakIntervals(from: dayStart, to: dayEnd).isEmpty
    }

    /// Upcoming peak windows (full ranges, not clipped).
    func upcomingPeakWindows(after now: Date, count: Int = 3) -> [DateInterval] {
        let peaks = peakIntervals(from: now, to: now.addingTimeInterval(21 * 86_400))
        return Array(peaks.filter { $0.start > now }.prefix(count))
    }

    /// Peak windows crossing the local day containing date, clipped to that day.
    func peakWindows(inLocalDayContaining date: Date, timeZone: TimeZone) -> [DateInterval] {
        let calendar = DeepSeekClock.calendar(in: timeZone)
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart), dayEnd > dayStart else {
            return []
        }
        let bounds = DateInterval(start: dayStart, end: dayEnd)
        let peaks = peakIntervals(from: dayStart.addingTimeInterval(-86_400),
                                  to: dayEnd.addingTimeInterval(86_400))
        return peaks.compactMap { $0.intersection(with: bounds) }
    }
}
