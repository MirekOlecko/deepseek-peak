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

    /// "Peak: 01:00-04:00, 06:00-10:00 UTC (Mon-Fri)"
    static func utcLine(_ schedule: PeakSchedule) -> String {
        guard !schedule.rules.isEmpty else { return "No peak windows defined" }
        let groups = Dictionary(grouping: schedule.rules) { $0.weekdays }
        let parts: [String] = groups.map { entry in
            let windows = entry.value
                .sorted { $0.startMinuteUTC < $1.startMinuteUTC }
                .map { TimeFormat.hhmm(minutesUTC: $0.startMinuteUTC) + "-" + TimeFormat.hhmm(minutesUTC: $0.endMinuteUTC) }
                .joined(separator: ", ")
            return windows + " UTC (" + weekdaysLabel(entry.key) + ")"
        }
        return "Peak: " + parts.sorted().joined(separator: " · ")
    }

    /// "Today (London): 02:00-05:00 · 07:00-11:00"
    static func localDayLine(_ schedule: PeakSchedule, day: Date, timeZone: TimeZone) -> String {
        let zone = TimeFormat.zoneLabel(timeZone)
        let windows = schedule.peakWindows(inLocalDayContaining: day, timeZone: timeZone)
        guard !windows.isEmpty else {
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

    /// Short state line for the menu bar and notifications.
    static func headline(_ status: RateStatus, now: Date, timeZone: TimeZone) -> String {
        if status.isPeak {
            return "PEAK (2x) until " + TimeFormat.hhmm(status.windowEnd, timeZone: timeZone)
        }
        return "OFF-PEAK (-50%) until " + TimeFormat.hhmm(status.windowEnd, timeZone: timeZone)
    }
}
