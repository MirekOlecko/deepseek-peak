import AppKit
import SwiftUI
import DeepSeekPeakCore

/// Renders the widget to a PNG. Usage: DeepSeekPeak --render file.png [--compact] [--at ISO8601]
///
/// `--at` freezes the clock, so holiday and peak behaviour can be rendered for any date.
@MainActor
enum PreviewRenderer {

    static func render(to path: String, compact: Bool, at date: Date? = nil) {
        _ = NSApplication.shared

        let defaults = UserDefaults(suiteName: "DeepSeekPeakPreview") ?? .standard
        let preferences = Preferences(defaults: defaults)
        preferences.compact = compact

        let model = ClockModel(schedule: .deepSeekDefault, now: date ?? Date())
        let controller = AppController()

        let content = WidgetView(model: model, preferences: preferences, controller: controller, rendersForPreview: true)
            .frame(width: WidgetPanelController.width)
            .background(Color(red: 0.12, green: 0.12, blue: 0.13))

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Could not render the preview\n".utf8))
            return
        }

        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Preview saved: " + path + " (" + String(rep.pixelsWide) + "x" + String(rep.pixelsHigh) + ")")
        } catch {
            FileHandle.standardError.write(Data(("Write failed: " + error.localizedDescription + "\n").utf8))
        }
    }
}
