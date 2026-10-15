import SwiftUI

struct DesktopClockView: View {
    @AppStorage("clock.size") private var size = WidgetSize.small
    @AppStorage("clock.style") private var style = ClockStyle.digital
    @AppStorage("clock.use24") private var use24 = true
    @AppStorage("clock.showAMPM") private var showAMPM = true
    @AppStorage("clock.accent") private var accentPreset = AccentPreset.standard.rawValue
    @AppStorage("clock.hex") private var accentHex = ""

    private var accent: Color { Accent.resolve(preset: accentPreset, hex: accentHex, fallback: .white) }

    private var digitalAccent: Color {
        Accent.resolve(preset: accentPreset, hex: accentHex,
                       fallback: Color(red: 1, green: 0.82, blue: 0.45))
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            face(for: context.date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func face(for date: Date) -> some View {
        // "Both" needs the wide size; small falls back to digital.
        let effective: ClockStyle = (size == .small && style == .both) ? .digital : style
        switch effective {
        case .digital:
            DigitalFace(date: date, use24: use24, showAMPM: showAMPM, accent: digitalAccent, big: size == .wide)
        case .analog:
            AnalogFace(date: date, accent: accent).padding(9)
        case .both:
            HStack(spacing: 6) {
                DigitalFace(date: date, use24: use24, showAMPM: showAMPM, accent: digitalAccent, big: false)
                AnalogFace(date: date, accent: accent).padding(.vertical, 10)
            }
            .padding(.horizontal, 12)
        }
    }
}

private struct DigitalFace: View {
    let date: Date
    let use24: Bool
    let showAMPM: Bool
    let accent: Color
    let big: Bool

    private func format(_ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(format(use24 ? "HH:mm" : "h:mm"))
                .font(.system(size: big ? 43 : 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 1, green: 0.98, blue: 0.93),
                             Color.white.mix(with: accent, by: 0.38)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if !use24 && showAMPM {
                Text(format("a"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Ink.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct AnalogFace: View {
    let date: Date
    let accent: Color

    var body: some View {
        let cal = Calendar.current
        let minute = Double(cal.component(.minute, from: date))
        let hour = Double(cal.component(.hour, from: date) % 12)
        let minuteAngle = minute * 6
        let hourAngle = hour * 30 + minute * 0.5

        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let tick = s * 0.09
            ZStack {
                Circle().stroke(.white.opacity(0.3), lineWidth: 1.5)
                // Ticks at 12, 3, 6 and 9.
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(accent.opacity(0.9))
                        .frame(width: 2, height: tick)
                        .offset(y: -(s / 2) + tick / 2 + s * 0.05)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
                Capsule().fill(accent)
                    .frame(width: 3.5, height: s * 0.24)
                    .offset(y: -s * 0.12)
                    .rotationEffect(.degrees(hourAngle))
                Capsule().fill(accent)
                    .frame(width: 2.5, height: s * 0.36)
                    .offset(y: -s * 0.18)
                    .rotationEffect(.degrees(minuteAngle))
                Circle().fill(accent).frame(width: 6, height: 6)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}
