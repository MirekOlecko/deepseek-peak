import AppKit
import Foundation
import DeepSeekPeakCore

/// Loads the schedule from ~/Library/Application Support/DeepSeekPeak/schedule.json,
/// so a DeepSeek price change never requires rebuilding the app.
enum ScheduleStore {

    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("DeepSeekPeak", isDirectory: true)
    }

    static var fileURL: URL {
        directoryURL.appendingPathComponent("schedule.json")
    }

    static func load() -> PeakSchedule {
        let holidays = HolidayStore.load()
        var schedule: PeakSchedule
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(PeakSchedule.self, from: data),
           !decoded.rules.isEmpty {
            schedule = decoded
        } else {
            schedule = .deepSeekDefault
        }
        schedule.holidays = holidays
        return schedule
    }

    static var isUsingCustomFile: Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let schedule = try? JSONDecoder().decode(PeakSchedule.self, from: data) else {
            return false
        }
        return !schedule.rules.isEmpty
    }

    /// Creates the file with the default schedule if it does not exist yet.
    @discardableResult
    static func writeDefaultIfMissing() -> URL {
        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(PeakSchedule.deepSeekDefault) {
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
