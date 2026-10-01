import AppKit
import Foundation
import DeepSeekPeakCore

/// Loads Chinese public holiday dates from
/// ~/Library/Application Support/DeepSeekPeak/holidays.json.
///
/// The State Council publishes the next year's dates in November, so a shipped app
/// would otherwise go stale every January. A year listed in the file replaces the
/// bundled year completely, which makes it possible to add next year and to correct
/// a date without rebuilding the application.
enum HolidayStore {

    static var fileURL: URL {
        ScheduleStore.directoryURL.appendingPathComponent("holidays.json")
    }

    /// Bundled official dates overlaid with the user's file, when one exists.
    static func load() -> HolidayCalendar {
        guard let data = try? Data(contentsOf: fileURL),
              let custom = try? JSONDecoder().decode(HolidayCalendar.self, from: data),
              !custom.years.isEmpty else {
            return .official
        }
        return HolidayCalendar.official.merging(custom)
    }

    /// True when the user file adds or overrides at least one year.
    static var isUsingCustomFile: Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let custom = try? JSONDecoder().decode(HolidayCalendar.self, from: data) else {
            return false
        }
        return !custom.years.isEmpty
    }

    @discardableResult
    static func writeDefaultIfMissing() -> URL {
        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: ScheduleStore.directoryURL,
                                                     withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(HolidayCalendar.official) {
                try? data.write(to: url, options: .atomic)
            }
        }
        return url
    }

    static func openInEditor() {
        let url = writeDefaultIfMissing()
        NSWorkspace.shared.open(url)
    }

    static func revealInFinder() {
        let url = writeDefaultIfMissing()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
