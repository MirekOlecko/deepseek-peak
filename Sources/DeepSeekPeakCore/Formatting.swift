import Foundation

public enum DurationFormat {

    /// "03:12:05" or "1d 04:12:05" - the live countdown.
    public static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let hms = String(format: "%02d:%02d:%02d", hours, minutes, secs)
        return days > 0 ? "\(days)d \(hms)" : hms
    }

    /// "3h 12m" - compact human text.
    public static func humanized(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        var parts: [String] = []
        if days > 0 {
            parts.append(days == 1 ? "1 day" : "\(days) days")
        }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0, days == 0 { parts.append("\(minutes)m") }
        if parts.isEmpty { parts.append("less than a minute") }
        return parts.joined(separator: " ")
    }

    /// "3:12" or "12:34" - short form for the menu bar.
    public static func menuBarShort(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return String(format: "%d:%02d", hours, minutes) }
        return String(format: "%d:%02d", minutes, total % 60)
    }
}

public enum TimeFormat {

    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ format: String, _ timeZone: TimeZone) -> DateFormatter {
        let key = format + "|" + timeZone.identifier
        if let cached = cache[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        cache[key] = formatter
        return formatter
    }

    public static func hhmm(_ date: Date, timeZone: TimeZone) -> String {
        formatter("HH:mm", timeZone).string(from: date)
    }

    public static func hhmmss(_ date: Date, timeZone: TimeZone) -> String {
        formatter("HH:mm:ss", timeZone).string(from: date)
    }

    /// "01:00" built from a minute offset from UTC midnight.
    public static func hhmm(minutesUTC: Int) -> String {
        let minutes = ((minutesUTC % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// "Thu"
    public static func weekdayShort(_ date: Date, timeZone: TimeZone) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let weekday = DeepSeekClock.calendar(in: timeZone).component(.weekday, from: date)
        return names[max(0, min(6, weekday - 1))]
    }

    /// "Thu 02:00"
    public static func dayAndTime(_ date: Date, timeZone: TimeZone) -> String {
        weekdayShort(date, timeZone: timeZone) + " " + hhmm(date, timeZone: timeZone)
    }

    /// "02:00-05:00"
    public static func range(_ interval: DateInterval, timeZone: TimeZone) -> String {
        hhmm(interval.start, timeZone: timeZone) + "-" + hhmm(interval.end, timeZone: timeZone)
    }

    /// Short zone name, e.g. "London" for "Europe/London".
    public static func zoneLabel(_ timeZone: TimeZone) -> String {
        if let last = timeZone.identifier.split(separator: "/").last, !last.isEmpty {
            return String(last).replacingOccurrences(of: "_", with: " ")
        }
        return timeZone.identifier
    }
}
