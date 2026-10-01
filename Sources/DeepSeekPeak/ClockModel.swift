import Foundation
import Combine
import DeepSeekPeakCore

/// Application clock: recomputes the rate state once per second.
@MainActor
final class ClockModel: ObservableObject {

    @Published private(set) var now: Date
    @Published private(set) var status: RateStatus
    @Published private(set) var schedule: PeakSchedule

    /// Called the moment the rate changes (peak <-> off-peak).
    var onTransition: ((RatePeriod, RateStatus) -> Void)?
    /// Called once per holiday that suspends peak windows on a day that would
    /// otherwise be a peak day.
    var onHolidaySuspension: ((ChineseHoliday, RateStatus) -> Void)?

    private var timer: Timer?
    /// Holiday already announced in this session; seeded at launch so starting the
    /// app during a holiday does not post a notification.
    private var announcedHolidayStart: String?

    init(schedule: PeakSchedule, now: Date = Date()) {
        self.schedule = schedule
        self.now = now
        let initial = schedule.status(at: now)
        self.status = initial
        self.announcedHolidayStart = initial.activeHoliday?.start
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick(at date: Date = Date()) {
        now = date
        let updated = schedule.status(at: date)
        let changed = updated.period != status.period
        status = updated
        if changed {
            onTransition?(updated.period, updated)
        }
        if let holiday = updated.activeHoliday,
           holiday.start != announcedHolidayStart,
           schedule.wouldBePeakDayWithoutHolidays(on: date) {
            announcedHolidayStart = holiday.start
            onHolidaySuspension?(holiday, updated)
        }
    }

    func apply(schedule: PeakSchedule) {
        self.schedule = schedule
        tick()
    }
}
