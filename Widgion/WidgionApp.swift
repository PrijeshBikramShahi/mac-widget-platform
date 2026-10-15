import SwiftUI
import AppKit

final class MiniAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        DesktopWidgetManager.shared.start()
        MiniPlayerWindow.show()
    }
}

struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var layout = LayoutController.shared

    var body: some View {
        Toggle("Edit layout", isOn: $layout.isEditing)
        Divider()
        Button("Show / Hide Widgets") { DesktopWidgetManager.shared.toggleVisibility() }
        Button("Show / Hide Player") { MiniPlayerWindow.toggle() }
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Widgion") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@main
struct WidgionApp: App {
    @NSApplicationDelegateAdaptor(MiniAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Widgion", systemImage: "square.grid.2x2") {
            MenuContent()
        }
        Window("Widgion Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
