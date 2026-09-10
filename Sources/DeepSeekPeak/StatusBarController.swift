import AppKit
import Combine
import DeepSeekPeakCore

/// Menu bar item with the countdown and the full menu.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private let model: ClockModel
    private let preferences: Preferences
    private let controller: AppController
    private var cancellables = Set<AnyCancellable>()

    init(model: ClockModel, preferences: Preferences, controller: AppController) {
        self.model = model
        self.preferences = preferences
        self.controller = controller
        super.init()
        model.$status
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            createIfNeeded()
        } else {
            remove()
        }
    }

    private func createIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refreshTitle()
    }

    private func remove() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    private func refreshTitle() {
        guard let button = statusItem?.button else { return }
        let status = model.status
        let marker = status.isPeak ? "🔴" : "🟢"
        button.title = marker + " " + DurationFormat.menuBarShort(status.remaining(at: model.now))
        button.toolTip = ScheduleSummary.headline(status, now: model.now, timeZone: .current)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let zone = TimeZone.current
        let status = model.status

        menu.addItem(info(ScheduleSummary.headline(status, now: model.now, timeZone: zone)))
        menu.addItem(info(ScheduleSummary.nextWindowLine(status, now: model.now, timeZone: zone)))
        menu.addItem(info(ScheduleSummary.localDayLine(model.schedule, day: model.now, timeZone: zone)))
        menu.addItem(.separator())

        menu.addItem(toggle("Show widget", #selector(toggleWidget), isOn: preferences.widgetVisible))
        menu.addItem(toggle("Compact mode", #selector(toggleCompact), isOn: preferences.compact))
        menu.addItem(toggle("Always on top", #selector(toggleAlwaysOnTop), isOn: preferences.alwaysOnTop))
        menu.addItem(toggle("On the desktop (behind windows)", #selector(toggleDesktopLevel), isOn: preferences.desktopLevel))
        menu.addItem(toggle("Rate change notifications", #selector(toggleNotifications), isOn: preferences.notificationsEnabled))
        menu.addItem(toggle("Launch at login", #selector(toggleLoginItem), isOn: controller.loginItemEnabled))
        menu.addItem(.separator())

        menu.addItem(action("Reload schedule", #selector(reloadSchedule)))
        menu.addItem(action("Edit schedule (schedule.json)", #selector(openSchedule)))
        menu.addItem(action("DeepSeek pricing in browser", #selector(openDocs)))
        menu.addItem(action("Move widget to default position", #selector(recenter)))
        menu.addItem(.separator())
        menu.addItem(action("Quit DeepSeek Peak", #selector(quit), key: "q"))
    }

    private func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func toggle(_ title: String, _ selector: Selector, isOn: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleWidget() { controller.toggleWidget() }
    @objc private func toggleCompact() { preferences.compact.toggle() }
    @objc private func toggleNotifications() { controller.toggleNotifications() }
    @objc private func toggleLoginItem() { controller.toggleLoginItem() }
    @objc private func reloadSchedule() { controller.reloadSchedule() }
    @objc private func openSchedule() { controller.openScheduleFile() }
    @objc private func openDocs() { controller.openPricingDocs() }
    @objc private func recenter() { controller.recenterWidget() }
    @objc private func quit() { controller.quit() }

    @objc private func toggleAlwaysOnTop() {
        preferences.alwaysOnTop.toggle()
        if preferences.alwaysOnTop { preferences.desktopLevel = false }
    }

    @objc private func toggleDesktopLevel() {
        preferences.desktopLevel.toggle()
        if preferences.desktopLevel { preferences.alwaysOnTop = false }
    }
}
