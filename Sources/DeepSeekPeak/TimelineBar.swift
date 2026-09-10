import SwiftUI
import DeepSeekPeakCore

enum Palette {
    static let peak = Color(red: 1.00, green: 0.31, blue: 0.36)
    static let peakDeep = Color(red: 0.68, green: 0.08, blue: 0.16)
    static let offPeak = Color(red: 0.24, green: 0.82, blue: 0.58)
    static let offPeakDeep = Color(red: 0.05, green: 0.45, blue: 0.34)
}

/// Pulsing status dot.
struct PulsingDot: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(0.9), radius: animating ? 6 : 1.5)
            .scaleEffect(animating ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

/// Progress bar for the current window.
struct ProgressLine: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(2, geometry.size.width * CGFloat(min(1, max(0, progress)))))
            }
        }
        .frame(height: 4)
    }
}

/// Timeline of the next 24 hours: red = peak, green = off-peak.
struct TimelineBar: View {
    let segments: [RateSegment]
    let start: Date
    let end: Date
    let timeZone: TimeZone

    private var total: TimeInterval { max(1, end.timeIntervalSince(start)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    ForEach(segments.indices, id: \.self) { index in
                        segment(segments[index], width: geometry.size.width)
                    }
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 1.5)
                        .shadow(color: Color.white.opacity(0.7), radius: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 22)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach(tickMarks.indices, id: \.self) { index in
                        Text(tickMarks[index].label)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .fixedSize()
                            .offset(x: labelOffset(fraction: tickMarks[index].fraction, width: geometry.size.width))
                    }
                }
            }
            .frame(height: 10)
        }
    }

    private func labelOffset(fraction: Double, width: CGFloat) -> CGFloat {
        let raw = width * CGFloat(fraction) - 9
        return min(max(0, raw), max(0, width - 24))
    }

    @ViewBuilder
    private func segment(_ segment: RateSegment, width: CGFloat) -> some View {
        let x = width * CGFloat(segment.start.timeIntervalSince(start) / total)
        let w = max(1, width * CGFloat(segment.duration / total))

        ZStack(alignment: .leading) {
            Rectangle()
                .fill(segment.isPeak
                      ? LinearGradient(colors: [Palette.peak, Palette.peakDeep], startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Palette.offPeak.opacity(0.7), Palette.offPeakDeep.opacity(0.85)],
                                       startPoint: .top,
                                       endPoint: .bottom))
            if segment.isPeak, w > 38 {
                Text(TimeFormat.hhmm(segment.start, timeZone: timeZone))
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.leading, 4)
                    .fixedSize()
            }
        }
        .frame(width: w, height: 22)
        .offset(x: x)
    }

    /// Time marks on full local hours, every 4 hours.
    private var tickMarks: [(label: String, fraction: Double)] {
        var marks: [(String, Double)] = [("now", 0)]
        let calendar = DeepSeekClock.calendar(in: timeZone)

        // Jump to the next full local hour...
        let components = calendar.dateComponents([.minute, .second], from: start)
        let secondsIntoHour = (components.minute ?? 0) * 60 + (components.second ?? 0)
        var cursor = start.addingTimeInterval(TimeInterval(3600 - secondsIntoHour))

        // ...then forward to an hour divisible by 4.
        var guardCount = 0
        while guardCount < 4, calendar.component(.hour, from: cursor) % 4 != 0 {
            cursor = cursor.addingTimeInterval(3600)
            guardCount += 1
        }

        // The first mark must not collide with the "now" label.
        if cursor.timeIntervalSince(start) < 3 * 3600 {
            cursor = cursor.addingTimeInterval(4 * 3600)
        }

        while cursor < end, marks.count < 8 {
            marks.append((TimeFormat.hhmm(cursor, timeZone: timeZone), cursor.timeIntervalSince(start) / total))
            cursor = cursor.addingTimeInterval(4 * 3600)
        }
        return marks
    }
}
