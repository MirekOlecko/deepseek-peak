import SwiftUI
import DeepSeekPeakCore

/// Main widget content.
struct WidgetView: View {

    @ObservedObject var model: ClockModel
    @ObservedObject var preferences: Preferences
    let controller: AppController
    var rendersForPreview = false

    private var status: RateStatus { model.status }
    private var accent: Color { status.isPeak ? Palette.peak : Palette.offPeak }
    private var timeZone: TimeZone { TimeZone.current }

    var body: some View {
        VStack(alignment: .leading, spacing: preferences.compact ? 8 : 12) {
            header
            countdown
            if !preferences.compact {
                TimelineBar(segments: status.timeline,
                            start: model.now,
                            end: model.now.addingTimeInterval(86_400),
                            timeZone: timeZone)
                details
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, preferences.compact ? 11 : 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LinearGradient(colors: [accent.opacity(0.95), accent.opacity(0.04)],
                                     startPoint: .top,
                                     endPoint: .bottom))
                .frame(height: 3)
        }
        .environment(\.colorScheme, .dark)
        .contextMenu {
            SettingsMenuContent(model: model, preferences: preferences, controller: controller)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            PulsingDot(color: accent)
            Text(headerTitle)
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(accent)
                .fixedSize()
            Spacer(minLength: 4)
            if rendersForPreview {
                // ImageRenderer cannot rasterize AppKit-backed menu controls.
                // The static preview uses the same label; the live app keeps its menu.
                settingsIcon
            } else {
                Menu {
                    SettingsMenuContent(model: model, preferences: preferences, controller: controller)
                } label: {
                    settingsIcon
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
    }

    /// Rate first, reason second: a holiday shows as off-peak, with the cause appended.
    private var headerTitle: String {
        if status.isPeak { return "PEAK — DOUBLE RATE" }
        return status.isHolidaySuspended ? "OFF-PEAK — 50% OFF · CN HOLIDAY" : "OFF-PEAK — 50% OFF"
    }

    private var settingsIcon: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.5))
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(status.isPeak ? "Peak ends in" : "Next peak starts in")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .fixedSize()
            Text(DurationFormat.countdown(status.remaining(at: model.now)))
                .font(.system(size: preferences.compact ? 30 : 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .fixedSize()
            if !preferences.compact {
                Text(windowLine)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .fixedSize()
            }
            ProgressLine(progress: status.elapsedFraction(at: model.now), color: accent)
                .padding(.top, 3)
        }
    }

    private var windowLine: String {
        let range = TimeFormat.range(DateInterval(start: status.windowStart, end: status.windowEnd),
                                     timeZone: timeZone)
        let prefix = status.isPeak ? "Peak window " : "Off-peak window "
        return prefix + range + " (" + TimeFormat.zoneLabel(timeZone) + ")"
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            detailRow("globe.europe.africa.fill", ScheduleSummary.utcLine(model.schedule))
            detailRow("clock.fill", ScheduleSummary.localDayLine(model.schedule,
                                                                day: model.now,
                                                                timeZone: timeZone,
                                                                holiday: status.activeHoliday))
            detailRow("arrow.forward.circle.fill", ScheduleSummary.nextWindowLine(status, now: model.now, timeZone: timeZone))
            if let holiday = ScheduleSummary.holidayLine(status) {
                detailRow("flag.fill", holiday)
            }
            if let warning = ScheduleSummary.holidayDataWarning(status) {
                detailRow("exclamationmark.triangle.fill", warning)
            }
        }
    }

    private func detailRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 8.5))
                .foregroundStyle(Color.white.opacity(0.35))
            Text(text)
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
