import SwiftUI
import AppKit

final class MiniAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MiniPlayerWindow.show()
    }
}

struct MenuContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
