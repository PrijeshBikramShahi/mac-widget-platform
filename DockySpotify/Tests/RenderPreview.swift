import AppKit
import SwiftUI

@main struct RenderPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let service = SpotifyService(observePlayback: false)
        service.apply(["paused", "Hey There Delilah", "Plain White T’s", "All That We Needed", "232000", "4", "55", "preview", ""])
        service.artwork = NSImage(size: NSSize(width: 200, height: 200), flipped: false) { rect in
            NSColor(calibratedRed: 0.85, green: 0.84, blue: 0.28, alpha: 1).setFill()
            rect.fill()
            NSColor.black.setFill()
            for x in stride(from: 8, to: 200, by: 43) {
                NSBezierPath(roundedRect: NSRect(x: x, y: 28, width: 30, height: 190), xRadius: 15, yRadius: 15).fill()
            }
            return true
        }
        for (name, width, height, expanded) in [("small", 58.0, 58.0, false), ("medium", 124.0, 58.0, false),
            ("wide", 190.0, 58.0, false), ("expanded", 360.0, 144.0, true), ("expanded-large", 480.0, 192.0, true)] {
            let view = DockySpotifyView(service: service, cornerRadius: 22, span: 2, expanded: expanded,
                                       connectOnAppear: false).frame(width: width, height: height)
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("\(name).png"))
            window.close()
        }
        print("Rendered all widget sizes.")
    }
}
