import WidgetKit
import SwiftUI

@main
struct WidgionWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        CalendarWidget()
        WeatherWidget()
        BatteryWidget()
    }
}
