import Foundation
import DeepSeekPeakCore

/// Human readable texts describing the schedule.
enum ScheduleSummary {

    static func weekdaysLabel(_ weekdays: Set<Int>) -> String {
        let sorted = weekdays.sorted()
        if sorted == [1, 2, 3, 4, 5, 6, 7] { return "daily" }
        if sorted == [2, 3, 4, 5, 6] { return "Mon-Fri" }
        if sorted == [1, 7] || sorted == [6, 7] { return "weekend" }
        let names = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        return sorted.map { names[$0] ?? "?" }.joined(separator: ", ")
    }

    /// "Peak: 01:00-04:00, 06:00-10:00 UTC · Mon-Fri, no CN holidays"
    ///
    /// Kept short on purpose: the widget shows this in a single line, and the holiday
    /// exclusion is part of the published rule rather than a footnote.
    static func utcLine(_ schedule: PeakSchedule) -> String {
        guard !schedule.rules.isEmpty else { return "No peak windows defined" }
        let groups = Dictionary(grouping: schedule.rules) { $0.weekdays }
        let parts: [String] = groups.map { entry in
            let windows = entry.value
                .sorted { $0.startMinuteUTC < $1.startMinuteUTC }
                .map { TimeFormat.hhmm(minutesUTC: $0.startMinuteUTC) + "-" + TimeFormat.hhmm(minutesUTC: $0.endMinuteUTC) }
                .joined(separator: ", ")
            return windows + " UTC · " + weekdaysLabel(entry.key)
        }
        let rule = parts.sorted().joined(separator: " · ")
        return "Peak: " + rule + (schedule.excludeChineseHolidays ? ", no CN holidays" : "")
    }

    /// "Today (London): 02:00-05:00 · 07:00-11:00"
    static func localDayLine(_ schedule: PeakSchedule,
                             day: Date,
                             timeZone: TimeZone,
                             holiday: ChineseHoliday? = nil) -> String {
        let zone = TimeFormat.zoneLabel(timeZone)
        let windows = schedule.peakWindows(inLocalDayContaining: day, timeZone: timeZone)
        guard !windows.isEmpty else {
            if let holiday {
                return "Today (" + zone + "): no peak - " + holiday.name + " in China"
            }
            return "Today (" + zone + "): no peak - 50% off all day"
        }
        let text = windows.map { TimeFormat.range($0, timeZone: timeZone) }.joined(separator: " · ")
        return "Today (" + zone + "): " + text
    }

    /// "Next peak: Fri 02:00-05:00 (in 8h 34m)"
    static func nextWindowLine(_ status: RateStatus, now: Date, timeZone: TimeZone) -> String {
        let label = status.isPeak ? "Following peak: " : "Next peak: "
        guard let start = status.nextPeakStart else {
            return label + "none in the coming weeks"
        }
        let end = status.nextPeakEnd ?? start.addingTimeInterval(3600)
        let when = DurationFormat.humanized(start.timeIntervalSince(now))
        return label + TimeFormat.dayAndTime(start, timeZone: timeZone)
            + "-" + TimeFormat.hhmm(end, timeZone: timeZone) + " (in " + when + ")"
    }

    /// "Oct 1-7" or "Oct 1" - the published Beijing dates.
    static func holidayRangeLabel(_ holiday: ChineseHoliday) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        func parts(_ day: String) -> (month: Int, day: Int)? {
            let pieces = day.split(separator: "-")
            guard pieces.count == 3, let month = Int(pieces[1]), let day = Int(pieces[2]),
                  (1...12).contains(month) else { return nil }
            return (month, day)
        }
        guard let start = parts(holiday.start), let end = parts(holiday.end) else {
            return holiday.start + " to " + holiday.end
        }
        let startLabel = months[start.month - 1] + " " + String(start.day)
        let endLabel = months[end.month - 1] + " " + String(end.day)
        if start == end { return startLabel }
        if start.month == end.month { return startLabel + "-" + String(end.day) }
        return startLabel + "-" + endLabel
    }

    /// "National Day in China (Oct 1-7) - peak suspended"
    static func holidayLine(_ status: RateStatus) -> String? {
        guard let holiday = status.activeHoliday else { return nil }
        return holiday.name + " in China (" + holidayRangeLabel(holiday) + ") - peak suspended"
    }

    /// "2027 holiday dates missing - weekdays shown as peak"
    static func holidayDataWarning(_ status: RateStatus) -> String? {
        guard let year = status.holidayDataMissingYear else { return nil }
        return String(year) + " holiday dates missing - weekdays shown as peak"
    }

    /// Longer wording for the menu bar, where there is room for a full sentence.
    static func holidayCoverageLine(_ schedule: PeakSchedule) -> String {
        guard schedule.excludeChineseHolidays else {
            return "Chinese public holidays: not excluded (see schedule.json)"
        }
        let years = schedule.holidays.coveredYears.sorted()
        guard let first = years.first, let last = years.last else {
            return "Chinese public holidays: no dates loaded"
        }
        let range = first == last ? String(first) : String(first) + "-" + String(last)
        return "Chinese public holidays excluded (" + range + ", Beijing dates)"
    }

    /// Full sentence for the menu bar warning item.
    static func holidayDataWarningLong(_ status: RateStatus) -> String? {
        guard let year = status.holidayDataMissingYear else { return nil }
        return "Holiday dates for " + String(year)
            + " are not published yet: weekday peak windows are assumed. Add them in holidays.json."
    }

    /// Short state line for the menu bar and notifications.
    static func headline(_ status: RateStatus, now: Date, timeZone: TimeZone) -> String {
        if status.isPeak {
            return "PEAK (2x) until " + TimeFormat.hhmm(status.windowEnd, timeZone: timeZone)
        }
        return "OFF-PEAK (-50%) until " + TimeFormat.hhmm(status.windowEnd, timeZone: timeZone)
    }
}
