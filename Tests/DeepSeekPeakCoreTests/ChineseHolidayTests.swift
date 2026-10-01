import XCTest
@testable import DeepSeekPeakCore

/// DeepSeek bills Chinese public holidays as off-peak in full:
/// "Peak hours are 01:00 - 04:00 and 06:00 - 10:00 UTC, Monday through Friday,
/// excluding Chinese public holidays."
final class ChineseHolidayTests: XCTestCase {

    private let schedule = PeakSchedule.deepSeekDefault

    private func utc(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: string) else {
            fatalError("Invalid test date: " + string)
        }
        return date
    }

    // 2026 National Day runs Thursday 1 October to Wednesday 7 October (Beijing).

    func testNationalDayFridayIsOffPeak() {
        // Friday 2026-10-02 02:00 UTC = 10:00 Beijing, normally inside the first peak window.
        let status = schedule.status(at: utc("2026-10-02T02:00:00Z"))
        XCTAssertFalse(status.isPeak)
        XCTAssertEqual(status.activeHoliday?.name, "National Day")
        XCTAssertEqual(status.nextPeakStart, utc("2026-10-08T01:00:00Z"))
    }

    func testEveryWeekdayOfNationalDayIsOffPeak() {
        // Thursday 1, Friday 2, Monday 5, Tuesday 6 and Wednesday 7 October.
        for day in ["2026-10-01", "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07"] {
            let status = schedule.status(at: utc(day + "T02:00:00Z"))
            XCTAssertFalse(status.isPeak, day + " must be off-peak")
            XCTAssertNotNil(status.activeHoliday, day + " must report the holiday")
            XCTAssertTrue(status.isHolidaySuspended)
        }
    }

    func testSpringFestivalTuesdayIsOffPeak() {
        let status = schedule.status(at: utc("2026-02-17T06:30:00Z"))
        XCTAssertFalse(status.isPeak)
        XCTAssertEqual(status.activeHoliday?.name, "Spring Festival")
    }

    func testPeakResumesOnTheFirstWeekdayAfterTheHoliday() {
        // Thursday 2026-10-08: the holiday ended at Beijing midnight (2026-10-07 16:00 UTC).
        XCTAssertFalse(schedule.status(at: utc("2026-10-07T16:30:00Z")).isPeak)
        let thursday = schedule.status(at: utc("2026-10-08T01:30:00Z"))
        XCTAssertTrue(thursday.isPeak)
        XCTAssertNil(thursday.activeHoliday)
        XCTAssertEqual(thursday.windowEnd, utc("2026-10-08T04:00:00Z"))
    }

    func testHolidayStartsAtBeijingMidnight() {
        // 2026-09-30 15:30 UTC = 23:30 Beijing (still a peak weekday),
        // 2026-09-30 16:30 UTC = 00:30 Beijing on 1 October (holiday).
        let custom = PeakSchedule(rules: [PeakRule(weekdays: [4], from: (15, 0), to: (17, 0))])
        XCTAssertTrue(custom.status(at: utc("2026-09-30T15:30:00Z")).isPeak)
        XCTAssertFalse(custom.status(at: utc("2026-09-30T16:30:00Z")).isPeak)

        // The window is split, not dropped: 15:00-16:00 UTC only.
        let windows = custom.peakIntervals(from: utc("2026-09-30T00:00:00Z"), to: utc("2026-10-01T00:00:00Z"))
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].start, utc("2026-09-30T15:00:00Z"))
        XCTAssertEqual(windows[0].end, utc("2026-09-30T16:00:00Z"))
    }

    func testTimelineHasNoPeakDuringTheHoliday() {
        let status = schedule.status(at: utc("2026-10-01T00:00:00Z"), horizon: 7 * 86_400)
        let peakSeconds = status.timeline.filter { $0.isPeak }.reduce(0) { $0 + $1.duration }
        // The horizon ends on Thursday 2026-10-08 00:00 UTC, before that day's 01:00 window.
        XCTAssertEqual(peakSeconds, 0, accuracy: 0.5)
    }

    func testUpcomingWindowsSkipHolidays() {
        let windows = schedule.upcomingPeakWindows(after: utc("2026-09-30T12:00:00Z"), count: 3)
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows[0].start, utc("2026-10-08T01:00:00Z"))
        XCTAssertEqual(windows[1].start, utc("2026-10-08T06:00:00Z"))
        XCTAssertEqual(windows[2].start, utc("2026-10-09T01:00:00Z"))
    }

    func testDisabledExclusionKeepsTheWeekdayPeak() {
        var plain = PeakSchedule.deepSeekDefault
        plain.excludeChineseHolidays = false
        let status = plain.status(at: utc("2026-10-02T02:00:00Z"))
        XCTAssertTrue(status.isPeak)
        XCTAssertNil(status.activeHoliday)
    }

    func testMissingYearIsReportedInsteadOfGuessed() {
        let official = HolidayCalendar.official
        XCTAssertTrue(official.hasData(forYear: 2025))
        XCTAssertTrue(official.hasData(forYear: 2026))
        XCTAssertFalse(official.hasData(forYear: 2027))

        // 2026-12-20 looks three weeks ahead, into 2027.
        let status = schedule.status(at: utc("2026-12-20T02:00:00Z"))
        XCTAssertEqual(status.holidayDataMissingYear, 2027)
    }

    func testHolidayCalendarMergesUserYears() {
        let custom = HolidayCalendar(years: [
            "2027": [ChineseHoliday(name: "New Year's Day", start: "2027-01-01", end: "2027-01-03")]
        ])
        let merged = HolidayCalendar.official.merging(custom)
        XCTAssertTrue(merged.hasData(forYear: 2026))
        XCTAssertTrue(merged.hasData(forYear: 2027))

        var withData = PeakSchedule.deepSeekDefault
        withData.holidays = merged
        // Friday 2027-01-01 is a holiday, so no peak that day.
        let status = withData.status(at: utc("2027-01-01T02:00:00Z"))
        XCTAssertFalse(status.isPeak)
        XCTAssertNil(status.holidayDataMissingYear)
    }

    func testHolidayIsReportedForTheBeijingDay() {
        // 2026-10-07 23:30 Beijing is the last holiday moment; 00:30 Beijing on the 8th is not.
        XCTAssertNotNil(HolidayCalendar.official.holiday(onBeijingDayContaining: utc("2026-10-07T15:30:00Z")))
        XCTAssertNil(HolidayCalendar.official.holiday(onBeijingDayContaining: utc("2026-10-07T16:30:00Z")))
    }

    func testScheduleJSONCarriesTheFlagButNotTheHolidayData() throws {
        let encoded = try JSONEncoder().encode(PeakSchedule.deepSeekDefault)
        let json = String(data: encoded, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("excludeChineseHolidays"))
        // The key itself must be absent; the note may still mention holidays in prose.
        XCTAssertFalse(json.contains("\"holidays\""))

        // A schedule written before holiday support defaults to DeepSeek's rule.
        let legacy = """
        {"note":"old","rules":[{"weekdays":[2,3,4,5,6],"startMinuteUTC":60,"endMinuteUTC":240}]}
        """
        let decoded = try JSONDecoder().decode(PeakSchedule.self, from: Data(legacy.utf8))
        XCTAssertTrue(decoded.excludeChineseHolidays)
        XCTAssertEqual(decoded.holidays.coveredYears, HolidayCalendar.official.coveredYears)

        let optedOut = PeakSchedule(rules: [PeakRule(weekdays: [2], startMinuteUTC: 60, endMinuteUTC: 240)],
                                    excludeChineseHolidays: false)
        let roundTrip = try JSONDecoder().decode(PeakSchedule.self, from: JSONEncoder().encode(optedOut))
        XCTAssertFalse(roundTrip.excludeChineseHolidays)
    }
}
