import SwiftUI

// All settings live in the app's own UserDefaults. Views read them with @AppStorage,
// and DesktopWidgetManager watches them, so changing a setting updates widgets live.

enum WidgetKind: String, CaseIterable {
    case clock, calendar, weather, battery
}

enum WidgetGrid {
    static let cell: CGFloat = 94
    static let gap: CGFloat = 16
    static let cornerRadius: CGFloat = 21

    static func size(columns: Int, rows: Int) -> CGSize {
        CGSize(width: cell * CGFloat(columns) + gap * CGFloat(columns - 1),
               height: cell * CGFloat(rows) + gap * CGFloat(rows - 1))
    }
}

enum PlayerSize: String, CaseIterable, Identifiable {
    case small, wide, large
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "1 × 1"
        case .wide: return "2 × 1"
        case .large: return "2 × 2"
        }
    }
    var points: CGSize {
        WidgetGrid.size(columns: self == .small ? 1 : 2, rows: self == .large ? 2 : 1)
    }
}

enum WidgetSize: String, CaseIterable, Identifiable {
    case small, wide
    var id: String { rawValue }
    var label: String { self == .small ? "Small" : "Wide" }
    var points: CGSize {
        WidgetGrid.size(columns: self == .small ? 1 : 2, rows: 1)
    }
}

enum ClockStyle: String, CaseIterable, Identifiable {
    case digital, analog, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .digital: return "Digital"
        case .analog: return "Analog"
        case .both: return "Both (wide only)"
        }
    }
}

enum BatteryStyle: String, CaseIterable, Identifiable {
    case ring, both, percent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ring: return "Ring"
        case .both: return "Ring + percentage"
        case .percent: return "Percentage only"
        }
    }
}

enum TempUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var label: String { self == .celsius ? "Celsius" : "Fahrenheit" }
}

enum GlassStyle: String, CaseIterable, Identifiable {
    case transparent = "transparent" // adjustable tint, with the wallpaper visible through it
    case clear = "clear"      // macOS 26 glass, most see-through
    case regular = "glass"    // macOS 26 glass, standard
    case frosted = "blur"     // classic light blur
    var id: String { rawValue }
    var label: String {
        switch self {
        case .transparent: return "Transparent"
        case .clear: return "Glass, clear"
        case .regular: return "Glass, regular"
        case .frosted: return "Frosted blur"
        }
    }
}

/// Text colors for the widgets. They are always white so they read on the light frost.
enum Ink {
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.75)
    static let tertiary = Color.white.opacity(0.55)
}

enum AccentPreset: String, CaseIterable, Identifiable {
    case standard, green, blue, orange, pink, purple, red, yellow, white
    var id: String { rawValue }
    var label: String { self == .standard ? "Default" : rawValue.capitalized }
    /// nil means "use the widget's own default color".
    var color: Color? {
        switch self {
        case .standard: return nil
        case .green: return Color(red: 0.20, green: 0.78, blue: 0.35)
        case .blue: return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .orange: return Color(red: 1.00, green: 0.62, blue: 0.04)
        case .pink: return Color(red: 1.00, green: 0.31, blue: 0.55)
        case .purple: return Color(red: 0.69, green: 0.32, blue: 0.87)
        case .red: return Color(red: 1.00, green: 0.27, blue: 0.23)
        case .yellow: return Color(red: 1.00, green: 0.84, blue: 0.04)
        case .white: return .white
        }
    }
}

extension Color {
    /// "#34C759" or "34C759". Returns nil if it isn't exactly six hex digits.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

enum Accent {
    /// A valid hex code wins; otherwise the preset; otherwise the widget's default.
    static func resolve(preset: String, hex: String, fallback: Color) -> Color {
        if let c = Color(hex: hex) { return c }
        return AccentPreset(rawValue: preset)?.color ?? fallback
    }
}

enum Prefs {
    static let defaults: [String: Any] = [
        "clock.enabled": true,
        "clock.size": WidgetSize.small.rawValue,
        "clock.style": ClockStyle.digital.rawValue,
        "clock.use24": true,
        "clock.showAMPM": true,
        "clock.accent": AccentPreset.standard.rawValue,
        "clock.hex": "",

        "calendar.enabled": true,
        "calendar.size": WidgetSize.small.rawValue,
        "calendar.display": CalendarDisplayMode.both.rawValue,
        "calendar.accent": AccentPreset.standard.rawValue,
        "calendar.hex": "",

        "weather.enabled": true,
        "weather.size": WidgetSize.wide.rawValue,
        "weather.city": "Kathmandu",
        "weather.units": TempUnit.celsius.rawValue,
        "weather.accent": AccentPreset.standard.rawValue,
        "weather.hex": "",

        "battery.enabled": true,
        "battery.style": BatteryStyle.both.rawValue,
        "battery.bolt": true,
        "battery.accent": AccentPreset.standard.rawValue,
        "battery.hex": "",

        "glass.style": GlassStyle.transparent.rawValue,
        "glass.opacity": 0.16,
        "player.enabled": true,
        "player.size": PlayerSize.large.rawValue,
        "player.artworkOnlyWhenIdle": false,
    ]

    static func register() { UserDefaults.standard.register(defaults: defaults) }

    static func enabled(_ kind: WidgetKind) -> Bool {
        UserDefaults.standard.bool(forKey: "\(kind.rawValue).enabled")
    }

    static func size(_ kind: WidgetKind) -> WidgetSize {
        if kind == .battery { return .small }   // battery is small only
        let raw = UserDefaults.standard.string(forKey: "\(kind.rawValue).size") ?? ""
        return WidgetSize(rawValue: raw) ?? .small
    }

    static var glass: GlassStyle {
        GlassStyle(rawValue: UserDefaults.standard.string(forKey: "glass.style") ?? "") ?? .transparent
    }

    static var playerSize: PlayerSize {
        PlayerSize(rawValue: UserDefaults.standard.string(forKey: "player.size") ?? "") ?? .large
    }

    static var city: String {
        (UserDefaults.standard.string(forKey: "weather.city") ?? "Kathmandu")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
