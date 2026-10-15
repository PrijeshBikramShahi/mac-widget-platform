import SwiftUI
import AppKit

final class MiniAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MiniPlayerWindow.show()
    }
}

@main
struct CWTestApp: App {
    @NSApplicationDelegateAdaptor(MiniAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
