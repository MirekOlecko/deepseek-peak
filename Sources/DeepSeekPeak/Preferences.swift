import AppKit
import Combine

/// Preferences persisted in UserDefaults.
@MainActor
final class Preferences: ObservableObject {

    private enum Key {
        static let widgetVisible = "widgetVisible"
        static let alwaysOnTop = "alwaysOnTop"
        static let desktopLevel = "desktopLevel"
        static let compact = "compact"
        static let notificationsEnabled = "notificationsEnabled"
        static let showMenuBar = "showMenuBar"
        static let panelOriginX = "panelOriginX"
        static let panelOriginY = "panelOriginY"
        static let panelHasOrigin = "panelHasOrigin"
    }

    private let defaults: UserDefaults

    @Published var widgetVisible: Bool {
        didSet { defaults.set(widgetVisible, forKey: Key.widgetVisible) }
    }
    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Key.alwaysOnTop) }
    }
    @Published var desktopLevel: Bool {
        didSet { defaults.set(desktopLevel, forKey: Key.desktopLevel) }
    }
    @Published var compact: Bool {
        didSet { defaults.set(compact, forKey: Key.compact) }
    }
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }
    @Published var showMenuBar: Bool {
        didSet { defaults.set(showMenuBar, forKey: Key.showMenuBar) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.widgetVisible: true,
            Key.alwaysOnTop: true,
            Key.desktopLevel: false,
            Key.compact: false,
            Key.notificationsEnabled: true,
            Key.showMenuBar: true
        ])
        widgetVisible = defaults.bool(forKey: Key.widgetVisible)
        alwaysOnTop = defaults.bool(forKey: Key.alwaysOnTop)
        desktopLevel = defaults.bool(forKey: Key.desktopLevel)
        compact = defaults.bool(forKey: Key.compact)
        notificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
        showMenuBar = defaults.bool(forKey: Key.showMenuBar)
    }

    var savedOrigin: CGPoint? {
        guard defaults.bool(forKey: Key.panelHasOrigin) else { return nil }
        return CGPoint(x: defaults.double(forKey: Key.panelOriginX),
                       y: defaults.double(forKey: Key.panelOriginY))
    }

    func save(origin: CGPoint) {
        defaults.set(Double(origin.x), forKey: Key.panelOriginX)
        defaults.set(Double(origin.y), forKey: Key.panelOriginY)
        defaults.set(true, forKey: Key.panelHasOrigin)
    }

    func resetOrigin() {
        defaults.set(false, forKey: Key.panelHasOrigin)
    }
}
