import SwiftUI
import ServiceManagement

struct ContentView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
        }
        .padding()
        .frame(width: 300)
        .onChange(of: launchAtLogin) { _, on in
            do {
                if on { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
}
