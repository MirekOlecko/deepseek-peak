import Foundation
import DeepSeekPeakCore

/// Diagnostic mode: prints the loaded schedule, holiday coverage and the current rate
/// state. Usage: DeepSeekPeak --status [--at ISO8601]
///
/// Useful after editing schedule.json or holidays.json: the output shows exactly what
/// the widget and the menu bar are showing.
@MainActor
enum ConfigDiagnostics {

    /// "2026-10-08" in UTC, so a date is never ambiguous in the output.
    private static func utcDay(_ date: Date) -> String {
        let parts = DeepSeekClock.utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func run(at date: Date?) {
        let schedule = ScheduleStore.load()
        let now = date ?? Date()
        let status = schedule.status(at: now)
        let utc = DeepSeekClock.utc

        print("now (UTC): " + TimeFormat.hhmmss(now, timeZone: utc)
              + " | local: " + TimeFormat.hhmmss(now, timeZone: .current))
        print("schedule: " + (ScheduleStore.isUsingCustomFile ? "schedule.json" : "built-in DeepSeek default"))
        print("holiday file: " + (HolidayStore.isUsingCustomFile ? "holidays.json (replaces bundled years)" : "none, bundled dates only"))
        let years = schedule.holidays.coveredYears.sorted().map(String.init).joined(separator: ", ")
        print("holiday years: " + (years.isEmpty ? "none" : years))
        print("exclude Chinese holidays: " + String(schedule.excludeChineseHolidays))
        print("period: " + status.period.rawValue)
        print("window (UTC): " + utcDay(status.windowStart) + " " + TimeFormat.hhmm(status.windowStart, timeZone: utc)
              + " to " + utcDay(status.windowEnd) + " " + TimeFormat.hhmm(status.windowEnd, timeZone: utc))
        if let holiday = status.activeHoliday {
            print("holiday today: " + holiday.name + " (" + holiday.start + " to " + holiday.end + ", Beijing)")
        }
        if let next = status.nextPeakStart, let end = status.nextPeakEnd {
            print("next peak (UTC): " + utcDay(next) + " " + TimeFormat.hhmm(next, timeZone: utc)
                  + "-" + TimeFormat.hhmm(end, timeZone: utc))
        } else {
            print("next peak (UTC): none in range")
        }
        if let year = status.holidayDataMissingYear {
            print("warning: holiday dates for " + String(year) + " are not published yet")
        }
        print("")
        print(ScheduleSummary.headline(status, now: now, timeZone: .current))
        print(ScheduleSummary.utcLine(schedule))
        print(ScheduleSummary.localDayLine(schedule, day: now, timeZone: .current, holiday: status.activeHoliday))
        print(ScheduleSummary.nextWindowLine(status, now: now, timeZone: .current))
        print(ScheduleSummary.holidayCoverageLine(schedule))
        if let warning = ScheduleSummary.holidayDataWarningLong(status) {
            print(warning)
        }
    }
}
