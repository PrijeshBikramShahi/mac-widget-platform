import SwiftUI
import Combine
import IOKit.ps

// MacBook battery only (Bluetooth device battery was cut from V1).

func readMacBattery() -> (percent: Int, charging: Bool)? {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
    for source in list {
        guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              let current = d[kIOPSCurrentCapacityKey] as? Int,
              let maxCap = d[kIOPSMaxCapacityKey] as? Int, maxCap > 0 else { continue }
        let charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
        return (current * 100 / maxCap, charging)
    }
    return nil
}

@MainActor
final class BatteryService: ObservableObject {
    static let shared = BatteryService()

    @Published private(set) var percent: Int?
    @Published private(set) var charging = false
    private var timer: Timer?

    private init() {
        read()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read() }
        }
    }

    private func read() {
        let b = readMacBattery()
        percent = b?.percent
        charging = b?.charging ?? false
    }
}

struct DesktopBatteryView: View {
    @ObservedObject private var service = BatteryService.shared
    @AppStorage("battery.style") private var style = BatteryStyle.both
    @AppStorage("battery.bolt") private var showBolt = true
    @AppStorage("battery.accent") private var accentPreset = AccentPreset.standard.rawValue
    @AppStorage("battery.hex") private var accentHex = ""

    private var accent: Color {
        Accent.resolve(preset: accentPreset, hex: accentHex, fallback: Color(red: 0.20, green: 0.78, blue: 0.35))
    }

    /// Accent normally; yellow below 50%; red at 20% or below. Charging always uses the accent.
    private func ringColor(_ p: Int, charging: Bool) -> Color {
        if charging { return accent }
        if p <= 20 { return .red }
        if p < 50 { return .yellow }
        return accent
    }

    var body: some View {
        Group {
            if let p = service.percent {
                let charging = service.charging
                let color = ringColor(p, charging: charging)
                let bolt = charging && showBolt

                VStack(spacing: 4) {
                    if style == .percent {
                        HStack(spacing: 2) {
                            if bolt { Image(systemName: "bolt.fill").font(.system(size: 14)).foregroundStyle(color) }
                            Text("\(p)%")
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .foregroundStyle((p <= 20 && !charging) ? Color.red : Color.white)
                        }
                    } else {
                        ZStack {
                            Circle().stroke(.white.opacity(0.15), lineWidth: 5.5)
                            Circle()
                                .trim(from: 0, to: Double(p) / 100)
                                .stroke(color, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 1) {
                                Image(systemName: "laptopcomputer")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.85))
                                if style == .ring && bolt {
                                    Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(color)
                                }
                            }
                        }
                        .frame(width: 52, height: 52)

                        if style == .both {
                            HStack(spacing: 2) {
                                if bolt { Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(color) }
                                Text("\(p)%").font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                    }
                }
            } else {
                Text("No battery")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Ink.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
