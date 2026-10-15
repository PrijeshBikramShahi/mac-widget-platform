import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettings()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            WidgetSelectionSettings()
                .tabItem { Label("Widgets", systemImage: "square.grid.2x2") }
            WidgetOptionsSettings()
                .tabItem { Label("Widget options", systemImage: "slider.horizontal.3") }
        }
        .padding(12)
        .frame(width: 520, height: 570)
    }
}

private struct AppearanceSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @AppStorage("glass.style") private var glass = GlassStyle.transparent
    @AppStorage("glass.opacity") private var backgroundOpacity = 0.16
    @ObservedObject private var layout = LayoutController.shared

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Window material", selection: $glass) {
                    ForEach(GlassStyle.allCases) { Text($0.label).tag($0) }
                }
                if glass == .transparent {
                    HStack {
                        Slider(value: $backgroundOpacity, in: 0...1, step: 0.01) {
                            Text("Background opacity")
                        }
                        Text(backgroundOpacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit().frame(width: 42, alignment: .trailing)
                    }
                    Text("Lower values reveal more wallpaper. Text stays opaque.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Layout") {
                Toggle("Edit layout", isOn: $layout.isEditing)
                Text("While editing, drag widgets or the player to align with 16-point gaps. Hold Option to place freely. Turn editing off to lock positions.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: launchAtLogin) { _, on in
            guard on != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if on { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
                loginError = nil
            } catch {
                loginError = "Couldn’t change launch at login. Check Login Items in System Settings."
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}

private struct WidgetSelectionSettings: View {
    @AppStorage("clock.enabled") private var clock = true
    @AppStorage("calendar.enabled") private var calendar = true
    @AppStorage("weather.enabled") private var weather = true
    @AppStorage("battery.enabled") private var battery = true
    @AppStorage("player.enabled") private var player = true

    var body: some View {
        Form {
            Section("Show on desktop") {
                Toggle("Clock", systemImage: "clock", isOn: $clock)
                Toggle("Calendar", systemImage: "calendar", isOn: $calendar)
                Toggle("Weather", systemImage: "cloud.sun", isOn: $weather)
                Toggle("Battery", systemImage: "battery.100percent", isOn: $battery)
                Toggle("Spotify player", systemImage: "music.note", isOn: $player)
            }
            Text("Choose Widget options to adjust each widget’s size, color, and content.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct WidgetOptionsSettings: View {
    @State private var selection = "Clock"
    private let options = ["Clock", "Calendar", "Weather", "Battery", "Spotify player"]

    var body: some View {
        Form {
            Picker("Widget", selection: $selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            switch selection {
            case "Clock": ClockSettings()
            case "Calendar": CalendarSettings()
            case "Weather": WeatherSettings()
            case "Battery": BatterySettings()
            default: PlayerSettings()
            }
        }
        .formStyle(.grouped)
    }
}

/// All previews use one scale, including the 16-point spacing between cells.
private struct SizeChoices<Value: Hashable>: View {
    @Binding var selection: Value
    let choices: [(value: Value, label: String, size: CGSize)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Size").font(.subheadline)
            HStack(spacing: 10) {
                ForEach(choices.indices, id: \.self) { index in
                    let choice = choices[index]
                    Button { selection = choice.value } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selection == choice.value ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                                .frame(width: choice.size.width * 0.23, height: choice.size.height * 0.23)
                                .frame(height: 48, alignment: .bottom)
                            Text(choice.label).font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selection == choice.value ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Size \(choice.label), \(Int(choice.size.width)) by \(Int(choice.size.height)) points")
                    .accessibilityAddTraits(selection == choice.value ? .isSelected : [])
                }
            }
        }
    }
}

private struct WidgetSizeChoices: View {
    @Binding var size: WidgetSize
    var body: some View {
        SizeChoices(selection: $size, choices: WidgetSize.allCases.map {
            ($0, $0 == .small ? "1 × 1" : "2 × 1", $0.points)
        })
    }
}

private struct PlayerSettings: View {
    @AppStorage("player.size") private var size = PlayerSize.large
    @AppStorage("player.artworkOnlyWhenIdle") private var artworkOnlyWhenIdle = false

    var body: some View {
        Section("Mini-player") {
            SizeChoices(selection: $size, choices: PlayerSize.allCases.map { ($0, $0.label, $0.points) })
            Toggle("Artwork only when idle", isOn: $artworkOnlyWhenIdle)
                .disabled(size == .wide)
            Text("For square sizes, hide the title and shading until you hover.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Hover for controls. Double-click artwork to open Spotify. Right-click for playback, size, and volume.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared accent controls

private struct AccentFields: View {
    @AppStorage private var preset: String
    @AppStorage private var hex: String

    init(_ kind: WidgetKind) {
        _preset = AppStorage(wrappedValue: AccentPreset.standard.rawValue, "\(kind.rawValue).accent")
        _hex = AppStorage(wrappedValue: "", "\(kind.rawValue).hex")
    }

    var body: some View {
        Picker("Accent color", selection: $preset) {
            ForEach(AccentPreset.allCases) { Text($0.label).tag($0.rawValue) }
        }
        TextField("Custom hex", text: $hex, prompt: Text("#34C759 (overrides the preset)"))
        if !hex.isEmpty && Color(hex: hex) == nil {
            Text("That isn't a valid hex code, so the preset is used.")
                .font(.caption).foregroundStyle(.red)
        }
    }
}

// MARK: - Per-widget sections

private struct ClockSettings: View {
    @AppStorage("clock.size") private var size = WidgetSize.small
    @AppStorage("clock.style") private var style = ClockStyle.digital
    @AppStorage("clock.use24") private var use24 = true
    @AppStorage("clock.showAMPM") private var showAMPM = true

    var body: some View {
        Section("Clock") {
            WidgetSizeChoices(size: $size)
            Picker("Style", selection: $style) {
                ForEach(ClockStyle.allCases) { Text($0.label).tag($0) }
            }
            Toggle("24-hour time", isOn: $use24)
            Toggle("Show AM/PM", isOn: $showAMPM).disabled(use24)
            AccentFields(.clock)
        }
    }
}

private struct CalendarSettings: View {
    @AppStorage("calendar.size") private var size = WidgetSize.small
    @AppStorage("calendar.display") private var display = CalendarDisplayMode.both

    var body: some View {
        Section("Calendar") {
            WidgetSizeChoices(size: $size)
            Picker("Dates", selection: $display) {
                ForEach(CalendarDisplayMode.allCases) { Text($0.label).tag($0) }
            }
            Text(display == .english
                 ? "English dates follow your Mac’s time zone."
                 : "Nepali and combined dates follow Nepal time (Asia/Kathmandu).")
                .font(.caption).foregroundStyle(.secondary)
            AccentFields(.calendar)
        }
    }
}

private struct WeatherSettings: View {
    @AppStorage("weather.size") private var size = WidgetSize.wide
    @AppStorage("weather.city") private var city = "Kathmandu"
    @AppStorage("weather.units") private var units = TempUnit.celsius
    @State private var draft = ""

    var body: some View {
        Section("Weather") {
            WidgetSizeChoices(size: $size)
            HStack {
                TextField("City", text: $draft, prompt: Text("Type a city, press Return"))
                    .onSubmit { city = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
                Button("Update") { city = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            Picker("Units", selection: $units) {
                ForEach(TempUnit.allCases) { Text($0.label).tag($0) }
            }
            AccentFields(.weather)
        }
        .onAppear { draft = city }
    }
}

private struct BatterySettings: View {
    @AppStorage("battery.style") private var style = BatteryStyle.both
    @AppStorage("battery.bolt") private var showBolt = true

    var body: some View {
        Section("Battery") {
            Text("1 × 1 · 94 × 94 points").font(.caption).foregroundStyle(.secondary)
            Picker("Style", selection: $style) {
                ForEach(BatteryStyle.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Show charging bolt", isOn: $showBolt)
            AccentFields(.battery)
        }
    }
}
