import AppKit
import DeepSeekPeakCore

/// Diagnostic mode: verifies that the window level follows preference changes made
/// at runtime (not only at launch). Usage: DeepSeekPeak --self-test-levels
///
/// Expected levels: desktop = -2147483602, normal = 0, floating = 3.
@MainActor
enum LevelSelfTest {

    static func run() async {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        let suite = "DeepSeekPeakSelfTest"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)

        let preferences = Preferences(defaults: defaults)
        preferences.alwaysOnTop = true
        preferences.desktopLevel = false
        preferences.compact = false

        let model = ClockModel(schedule: ScheduleStore.load())
        let controller = AppController()
        let panel = WidgetPanelController(model: model, preferences: preferences, controller: controller)
        panel.setVisible(true)

        func report(_ label: String) async {
            try? await Task.sleep(nanoseconds: 150_000_000)
            let size = Int(panel.currentSize.width)
            let height = Int(panel.currentSize.height)
            print("[" + label + "] desktopLevel=" + String(preferences.desktopLevel)
                  + " alwaysOnTop=" + String(preferences.alwaysOnTop)
                  + " compact=" + String(preferences.compact)
                  + " -> level=" + String(panel.currentLevel)
                  + " size=" + String(size) + "x" + String(height))
        }

        await report("start: alwaysOnTop")
        preferences.desktopLevel = true
        await report("desktopLevel=true (gear toggle)")
        preferences.desktopLevel = false
        preferences.alwaysOnTop = false
        await report("desktopLevel=false, alwaysOnTop=false")
        preferences.alwaysOnTop = true
        await report("alwaysOnTop=true")
        preferences.compact = true
        await report("compact=true")
        preferences.compact = false
        await report("compact=false")
    }
}
