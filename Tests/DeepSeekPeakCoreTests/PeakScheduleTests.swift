import XCTest
@testable import DeepSeekPeakCore

final class PeakScheduleTests: XCTestCase {

    private let schedule = PeakSchedule.deepSeekDefault

    private func utc(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: string) else {
            fatalError("Invalid test date: " + string)
        }
        return date
    }

    // 2026-09-10 is a Thursday, 2026-09-12 a Saturday, 2026-09-14 a Monday.

    func testPeakDuringFirstWindowOnThursday() {
        let now = utc("2026-09-10T03:00:00Z")
        let status = schedule.status(at: now)
        XCTAssertTrue(status.isPeak)
        XCTAssertEqual(status.windowStart, utc("2026-09-10T01:00:00Z"))
        XCTAssertEqual(status.windowEnd, utc("2026-09-10T04:00:00Z"))
        XCTAssertEqual(status.remaining(at: now), 3600, accuracy: 0.5)
    }

    func testGapBetweenWindowsIsOffPeak() {
        let now = utc("2026-09-10T05:00:00Z")
        let status = schedule.status(at: now)
        XCTAssertFalse(status.isPeak)
        XCTAssertEqual(status.windowEnd, utc("2026-09-10T06:00:00Z"))
        XCTAssertEqual(status.windowStart, utc("2026-09-10T04:00:00Z"))
    }

    func testAfternoonIsOffPeakAndNextPeakIsFridayMorning() {
        let now = utc("2026-09-10T16:19:51Z")
        let status = schedule.status(at: now)
        XCTAssertFalse(status.isPeak)
        XCTAssertEqual(status.nextPeakStart, utc("2026-09-11T01:00:00Z"))
        XCTAssertEqual(status.nextPeakEnd, utc("2026-09-11T04:00:00Z"))
        XCTAssertEqual(status.remaining(at: now), utc("2026-09-11T01:00:00Z").timeIntervalSince(now), accuracy: 0.5)
    }

    func testWeekendIsFullyOffPeak() {
        let now = utc("2026-09-12T02:00:00Z")
        let status = schedule.status(at: now)
        XCTAssertFalse(status.isPeak)
        XCTAssertEqual(status.nextPeakStart, utc("2026-09-14T01:00:00Z"))
    }

    func testWindowBoundariesAreHalfOpen() {
        let endOfFirstWindow = schedule.status(at: utc("2026-09-10T04:00:00Z"))
        XCTAssertFalse(endOfFirstWindow.isPeak)
        XCTAssertEqual(endOfFirstWindow.windowEnd, utc("2026-09-10T06:00:00Z"))

        let startOfFirstWindow = schedule.status(at: utc("2026-09-10T01:00:00Z"))
        XCTAssertTrue(startOfFirstWindow.isPeak)

        let fridayMorning = schedule.status(at: utc("2026-09-11T10:00:00Z"))
        XCTAssertFalse(fridayMorning.isPeak)
        XCTAssertEqual(fridayMorning.nextPeakStart, utc("2026-09-14T01:00:00Z"))
    }

    func testTimelineCoversHorizonWithoutGaps() {
        let now = utc("2026-09-10T00:00:00Z")
        let status = schedule.status(at: now, horizon: 24 * 3600)
        XCTAssertEqual(status.timeline.first?.start, now)
        XCTAssertEqual(status.timeline.last?.end, now.addingTimeInterval(24 * 3600))
        XCTAssertEqual(status.timeline.reduce(0) { $0 + $1.duration }, 24 * 3600, accuracy: 0.5)
        for (previous, next) in zip(status.timeline, status.timeline.dropFirst()) {
            XCTAssertEqual(previous.end, next.start)
            XCTAssertNotEqual(previous.isPeak, next.isPeak)
        }
    }

    func testTimelinePeakTotalIsSevenHoursOnAWeekday() {
        let now = utc("2026-09-10T00:00:00Z")
        let status = schedule.status(at: now, horizon: 24 * 3600)
        // Thursday: 3 hours (01:00-04:00) + 4 hours (06:00-10:00) = 7 hours of peak.
        let peakSeconds = status.timeline.filter { $0.isPeak }.reduce(0) { $0 + $1.duration }
        XCTAssertEqual(peakSeconds, 7 * 3600, accuracy: 0.5)
    }

    func testUpcomingWindows() {
        let now = utc("2026-09-12T12:00:00Z")
        let windows = schedule.upcomingPeakWindows(after: now, count: 3)
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows[0].start, utc("2026-09-14T01:00:00Z"))
        XCTAssertEqual(windows[0].end, utc("2026-09-14T04:00:00Z"))
        XCTAssertEqual(windows[1].start, utc("2026-09-14T06:00:00Z"))
        XCTAssertEqual(windows[2].start, utc("2026-09-15T01:00:00Z"))
    }

    func testLocalDayWindowsInLondon() {
        let london = TimeZone(identifier: "Europe/London")!
        // Thursday 2026-09-10 in London (BST = UTC+1 in September).
        let windows = schedule.peakWindows(inLocalDayContaining: utc("2026-09-10T10:00:00Z"), timeZone: london)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].start, utc("2026-09-10T01:00:00Z"))
        XCTAssertEqual(windows[0].end, utc("2026-09-10T04:00:00Z"))
        XCTAssertEqual(TimeFormat.range(windows[0], timeZone: london), "02:00-05:00")
        XCTAssertEqual(TimeFormat.range(windows[1], timeZone: london), "07:00-11:00")
    }

    func testLocalDayWindowsInWarsaw() {
        let warsaw = TimeZone(identifier: "Europe/Warsaw")!
        let windows = schedule.peakWindows(inLocalDayContaining: utc("2026-09-10T10:00:00Z"), timeZone: warsaw)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(TimeFormat.range(windows[0], timeZone: warsaw), "03:00-06:00")
        XCTAssertEqual(TimeFormat.range(windows[1], timeZone: warsaw), "08:00-12:00")
    }

    func testRuleDurations() {
        XCTAssertEqual(schedule.rules[0].duration, 3 * 3600, accuracy: 0.5)
        XCTAssertEqual(schedule.rules[1].duration, 4 * 3600, accuracy: 0.5)
    }

    func testCountdownFormatting() {
        XCTAssertEqual(DurationFormat.countdown(0), "00:00:00")
        XCTAssertEqual(DurationFormat.countdown(3661), "01:01:01")
        XCTAssertEqual(DurationFormat.countdown(90_000), "1d 01:00:00")
        XCTAssertEqual(DurationFormat.menuBarShort(3600), "1:00")
        XCTAssertEqual(DurationFormat.menuBarShort(59), "0:59")
        XCTAssertEqual(DurationFormat.humanized(3600 + 12 * 60), "1h 12m")
    }

    func testCustomScheduleJSONRoundTrip() throws {
        let schedule = PeakSchedule(rules: [
            PeakRule(weekdays: [1, 7], startMinuteUTC: 30, endMinuteUTC: 90)
        ])
        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(PeakSchedule.self, from: data)
        XCTAssertEqual(decoded, schedule)
        // Window 00:30-01:30 on a Sunday.
        let status = schedule.status(at: utc("2026-09-13T01:00:00Z"))
        XCTAssertTrue(status.isPeak)
        XCTAssertEqual(status.windowEnd, utc("2026-09-13T01:30:00Z"))
    }

    func testEmptyScheduleNeverReportsPeak() {
        let empty = PeakSchedule(rules: [])
        let status = empty.status(at: utc("2026-09-10T02:00:00Z"))
        XCTAssertFalse(status.isPeak)
        XCTAssertEqual(status.timeline.count, 1)
    }
}
