import SwiftUI

/// Shared menu content: the gear button inside the widget and the right-click menu.
struct SettingsMenuContent: View {

    @ObservedObject var model: ClockModel
    @ObservedObject var preferences: Preferences
    let controller: AppController

    var body: some View {
        Toggle("Compact mode", isOn: $preferences.compact)
        Toggle("Always on top", isOn: Binding(
            get: { preferences.alwaysOnTop },
            set: { newValue in
                preferences.alwaysOnTop = newValue
                if newValue { preferences.desktopLevel = false }
            }))
        Toggle("On the desktop (behind windows)", isOn: Binding(
            get: { preferences.desktopLevel },
            set: { newValue in
                preferences.desktopLevel = newValue
                if newValue { preferences.alwaysOnTop = false }
            }))
        Toggle("Menu bar icon", isOn: $preferences.showMenuBar)
        Toggle("Rate change notifications", isOn: $preferences.notificationsEnabled)

        Divider()

        Button(controller.loginItemTitle) { controller.toggleLoginItem() }
        Button("Move widget to default position") { controller.recenterWidget() }

        Divider()

        Button("Reload schedule & holiday dates") { controller.reloadSchedule() }
        Button("Edit schedule (schedule.json)") { controller.openScheduleFile() }
        Button("Edit holiday dates (holidays.json)") { controller.openHolidayFile() }
        Button("DeepSeek pricing in browser") { controller.openPricingDocs() }

        Divider()

        Button(preferences.widgetVisible ? "Hide widget" : "Show widget") { controller.toggleWidget() }
        Button("Quit DeepSeek Peak") { controller.quit() }
    }
}
