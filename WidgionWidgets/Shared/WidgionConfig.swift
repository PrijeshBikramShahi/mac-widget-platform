import Foundation

// Widget settings in one place. Edit values here for now.
// These move into an app-managed settings store, shared through an App Group, later.

enum BatteryStyle { case ring, percent, both }

enum WidgionConfig {
    // Clock
    static let use24Hour = true

    // Weather (Open-Meteo)
    static let weatherPlace = "Kathmandu"
    static let weatherLat = 27.7172
    static let weatherLon = 85.3240

    // Battery
    static let batteryStyle = BatteryStyle.both
}
