import AppKit
import Combine
import SwiftUI
import DeepSeekPeakCore

final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The widget window: frameless, transparent, draggable by its background.
@MainActor
final class WidgetPanelController {

    static let width: CGFloat = 344
    static let fallbackCompactHeight: CGFloat = 120
    static let fallbackExpandedHeight: CGFloat = 300

    private let panel: WidgetPanel
    private let visualEffect = NSVisualEffectView()
    private let hostingView: NSHostingView<WidgetView>
    private let preferences: Preferences
    private var cancellables = Set<AnyCancellable>()

    init(model: ClockModel, preferences: Preferences, controller: AppController) {
        self.preferences = preferences

        panel = WidgetPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.fallbackExpandedHeight),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.title = "DeepSeek Peak"

        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 18
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 1
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        hostingView = NSHostingView(rootView: WidgetView(model: model,
                                                         preferences: preferences,
                                                         controller: controller))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor)
        ])
        panel.contentView = visualEffect

        // @Published emits from willSet, so at this point the stored values are still
        // the old ones. Defer to the next main-actor turn and read the settled state.
        preferences.$compact
            .sink { [weak self] _ in
                Task { @MainActor in self?.updateSize(animated: true) }
            }
            .store(in: &cancellables)
        preferences.$alwaysOnTop
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyLevel() }
            }
            .store(in: &cancellables)
        preferences.$desktopLevel
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyLevel() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(panelDidMove),
                                               name: NSWindow.didMoveNotification,
                                               object: panel)

        applyLevel()
        updateSize(animated: false)
        restorePosition()
    }

    // MARK: - Visibility

    func setVisible(_ visible: Bool) {
        if visible {
            applyLevel()
            updateSize(animated: false)
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: - Window level

    func applyLevel() {
        // isFloatingPanel is applied first: AppKit resets the window level when it changes.
        if preferences.desktopLevel {
            panel.isFloatingPanel = false
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        } else if preferences.alwaysOnTop {
            panel.isFloatingPanel = true
            panel.level = .floating
        } else {
            panel.isFloatingPanel = false
            panel.level = .normal
        }
    }

    /// Current window level (diagnostics).
    var currentLevel: Int { panel.level.rawValue }

    /// Current window size (diagnostics).
    var currentSize: NSSize { panel.frame.size }

    // MARK: - Size

    func updateSize(animated: Bool) {
        hostingView.layoutSubtreeIfNeeded()
        var height = ceil(hostingView.fittingSize.height)
        if !height.isFinite || height < 70 || height > 800 {
            height = preferences.compact ? Self.fallbackCompactHeight : Self.fallbackExpandedHeight
        }
        var frame = panel.frame
        let topRight = NSPoint(x: frame.maxX, y: frame.maxY)
        frame.size = NSSize(width: Self.width, height: height)
        frame.origin = NSPoint(x: topRight.x - Self.width, y: topRight.y - height)
        panel.setFrame(frame, display: true, animate: animated)
    }

    // MARK: - Position

    func moveToDefaultPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: visible.maxX - size.width - 28, y: visible.maxY - size.height - 28)
        panel.setFrameOrigin(origin)
        preferences.save(origin: origin)
    }

    private func restorePosition() {
        let size = panel.frame.size
        if let origin = preferences.savedOrigin {
            let frame = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }
        moveToDefaultPosition()
    }

    @objc private func panelDidMove() {
        preferences.save(origin: panel.frame.origin)
    }

    // MARK: - Effects

    /// Flashes the widget when the rate changes.
    func flash() {
        guard panel.isVisible else { return }
        let panel = self.panel
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0.3
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                panel.animator().alphaValue = 1
            }
        })
    }
}
