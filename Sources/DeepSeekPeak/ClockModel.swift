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

    private var timer: Timer?

    init(schedule: PeakSchedule, now: Date = Date()) {
        self.schedule = schedule
        self.now = now
        self.status = schedule.status(at: now)
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
    }

    func apply(schedule: PeakSchedule) {
        self.schedule = schedule
        tick()
    }
}
