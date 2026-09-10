import AppKit

/// Entry point. The app runs as an agent (no Dock icon): the UI is a floating
/// desktop widget plus a menu bar item.
@main
struct DeepSeekPeakMain {

    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let arguments = CommandLine.arguments

        // Diagnostic mode: checks that the window level follows runtime preference changes.
        if arguments.contains("--self-test-levels") {
            runLevelSelfTest()
            return
        }

        // Helper mode: render a widget preview to a PNG file.
        if let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count {
            PreviewRenderer.render(to: arguments[index + 1], compact: arguments.contains("--compact"))
            exit(0)
        }

        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    /// Runs the diagnostic and never returns.
    @MainActor
    private static func runLevelSelfTest() -> Never {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            await LevelSelfTest.run()
            exit(0)
        }
        application.run()
        exit(0)
    }
}
