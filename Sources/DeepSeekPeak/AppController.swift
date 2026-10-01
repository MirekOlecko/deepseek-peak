import AppKit
import Combine
import DeepSeekPeakCore

/// Wires together the model, the widget window, the menu bar item and notifications.
@MainActor
final class AppController {

    let preferences: Preferences
    let model: ClockModel
    let notifier = Notifier()

    private var panelController: WidgetPanelController?
    private var statusBarController: StatusBarController?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []

    init() {
        preferences = Preferences()
        model = ClockModel(schedule: ScheduleStore.load())
    }

    func start() {
        ScheduleStore.writeDefaultIfMissing()
        HolidayStore.writeDefaultIfMissing()

        panelController = WidgetPanelController(model: model, preferences: preferences, controller: self)
        statusBarController = StatusBarController(model: model, preferences: preferences, controller: self)

        model.onTransition = { [weak self] period, status in
            self?.handleTransition(period: period, status: status)
        }

        model.onHolidaySuspension = { [weak self] holiday, status in
            guard let self, self.preferences.notificationsEnabled else { return }
            self.notifier.post(
                title: "DeepSeek peak skipped — Chinese public holiday",
                body: holiday.name + " (" + ScheduleSummary.holidayRangeLabel(holiday)
                    + ", Beijing dates): DeepSeek bills the whole day as off-peak. "
                    + ScheduleSummary.nextWindowLine(status, now: Date(), timeZone: TimeZone.current) + ".")
        }

        if preferences.notificationsEnabled {
            notifier.requestAuthorizationIfNeeded()
        }

        preferences.$widgetVisible
            .sink { [weak self] visible in self?.panelController?.setVisible(visible) }
            .store(in: &cancellables)

        preferences.$showMenuBar
            .sink { [weak self] visible in self?.statusBarController?.setVisible(visible) }
            .store(in: &cancellables)

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.model.tick() }
            })

        observers.append(NotificationCenter.default.addObserver(
            forName: Notification.Name.NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.model.tick() }
            })

        model.start()
    }

    // MARK: - Actions

    func toggleWidget() {
        preferences.widgetVisible.toggle()
    }

    func recenterWidget() {
        preferences.resetOrigin()
        panelController?.moveToDefaultPosition()
    }

    var loginItemEnabled: Bool { LoginItem.isEnabled }

    var loginItemTitle: String {
        loginItemEnabled ? "Disable launch at login" : "Launch at login"
    }

    func toggleLoginItem() {
        do {
            try LoginItem.set(enabled: !LoginItem.isEnabled)
        } catch {
            presentError("Could not change the launch at login setting", error)
        }
    }

    func toggleNotifications() {
        preferences.notificationsEnabled.toggle()
        if preferences.notificationsEnabled {
            notifier.requestAuthorizationIfNeeded()
        }
    }

    func reloadSchedule() {
        model.apply(schedule: ScheduleStore.load())
    }

    func openScheduleFile() {
        ScheduleStore.openInEditor()
    }

    func openHolidayFile() {
        HolidayStore.openInEditor()
    }

    func openChineseHolidayNotice() {
        guard let url = URL(string: "https://www.gov.cn/zhengce/") else { return }
        NSWorkspace.shared.open(url)
    }

    func openPricingDocs() {
        guard let url = URL(string: "https://api-docs.deepseek.com/quick_start/pricing") else { return }
        NSWorkspace.shared.open(url)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Rate changes

    private func handleTransition(period: RatePeriod, status: RateStatus) {
        panelController?.flash()
        guard preferences.notificationsEnabled else { return }

        let zone = TimeZone.current
        if period == .peak {
            notifier.post(title: "DeepSeek peak — double rate",
                          body: "The peak window runs until " + TimeFormat.hhmm(status.windowEnd, timeZone: zone)
                              + " local time. You are paying 2x the off-peak price.")
        } else {
            notifier.post(title: "DeepSeek off-peak — 50% off",
                          body: "Rates just halved and stay that way until "
                              + TimeFormat.hhmm(status.windowEnd, timeZone: zone)
                              + ". " + ScheduleSummary.nextWindowLine(status, now: Date(), timeZone: zone) + ".")
        }
    }

    private func presentError(_ title: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
