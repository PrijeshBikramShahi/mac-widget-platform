import SwiftUI
import AppKit

// Creates one transparent desktop-level window per enabled widget, the same way the Spotify
// player does: above the wallpaper and icons, below app windows, on every Space.
// It watches UserDefaults, so settings changes apply immediately.

@MainActor
final class DesktopWidgetManager {
    static let shared = DesktopWidgetManager()

    private var panels: [WidgetKind: NSPanel] = [:]
    private var appliedGlass: GlassStyle?
    private var started = false
    private var hidden = false
    private let cornerRadius = WidgetGrid.cornerRadius

    func start() {
        guard !started else { return }
        started = true
        reconcile()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
    }

    func toggleVisibility() {
        hidden.toggle()
        for p in panels.values {
            if hidden { p.orderOut(nil) } else { p.orderFrontRegardless() }
        }
    }

    // MARK: Keeping windows in line with settings (safe to call repeatedly)

    private func reconcile() {
        let glass = Prefs.glass
        let glassChanged = (glass != appliedGlass)
        appliedGlass = glass

        for kind in WidgetKind.allCases {
            guard Prefs.enabled(kind) else {
                if let p = panels.removeValue(forKey: kind) { p.orderOut(nil); p.close() }
                continue
            }
            let size = Prefs.size(kind).points
            if let p = panels[kind] {
                if glassChanged { install(kind, in: p) }
                resize(p, to: size)
            } else {
                panels[kind] = makePanel(kind, size: size)
            }
        }
    }

    private func makePanel(_ kind: WidgetKind, size: CGSize) -> NSPanel {
        let p = LayoutPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        LayoutController.shared.register(p)
        p.appearance = NSAppearance(named: .aqua)   // light, clear material; the text is always white

        install(kind, in: p)

        let name = "Widgion-\(kind.rawValue)"
        if !p.setFrameUsingName(name) { p.setFrameOrigin(defaultOrigin(for: kind, size: size)) }
        p.setFrameAutosaveName(name)
        resize(p, to: size)   // a saved frame may carry an old size

        if !hidden { p.orderFrontRegardless() }
        return p
    }

    private func resize(_ p: NSPanel, to size: CGSize) {
        let f = p.frame
        guard abs(f.width - size.width) > 0.5 || abs(f.height - size.height) > 0.5 else { return }
        // Keep the top-left corner where it is.
        p.setFrame(NSRect(x: f.minX, y: f.maxY - size.height, width: size.width, height: size.height),
                   display: true, animate: false)
    }

    private func defaultOrigin(for kind: WidgetKind, size: CGSize) -> NSPoint {
        let vf = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let preceding = WidgetKind.allCases.prefix { $0 != kind }.filter { Prefs.enabled($0) }
        let offset = preceding.reduce(CGFloat.zero) { $0 + Prefs.size($1).points.width + WidgetGrid.gap }
        return NSPoint(x: vf.minX + WidgetGrid.gap + offset,
                       y: vf.maxY - WidgetGrid.gap - size.height)
    }

    // MARK: Glass

    private func styled<V: View>(_ v: V) -> AnyView {
        AnyView(v.foregroundStyle(Ink.primary).shadow(color: .black.opacity(0.16), radius: 1.5, y: 0.5))
    }

    private func rootView(for kind: WidgetKind) -> AnyView {
        switch kind {
        case .clock: return styled(DesktopClockView())
        case .calendar: return styled(DesktopCalendarView())
        case .weather: return styled(DesktopWeatherView())
        case .battery: return styled(DesktopBatteryView())
        }
    }

    private func install(_ kind: WidgetKind, in panel: NSPanel) {
        let style = Prefs.glass
        let content = rootView(for: kind)
        let host = FirstMouseHostingView(rootView: AnyView(content.overlay { LayoutOutline() }.background {
            if style == .transparent {
                TransparentWidgetBackground(cornerRadius: cornerRadius)
            }
        }))
        host.sizingOptions = []   // the window decides the size, not the SwiftUI content

        if style == .transparent {
            panel.contentView = host
        } else if style != .frosted, #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.style = (style == .clear) ? .clear : .regular
            glass.contentView = host
            panel.contentView = glass
        } else {
            let fx = NSVisualEffectView()
            fx.material = .underWindowBackground   // other options: .popover, .menu, .sidebar
            fx.blendingMode = .behindWindow
            fx.state = .active
            fx.maskImage = Self.roundedMask(radius: cornerRadius)
            host.frame = fx.bounds
            host.autoresizingMask = [.width, .height]
            fx.addSubview(host)
            panel.contentView = fx
        }
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }
}

/// Tint only the background; fading the panel would also fade its text and icons.
struct TransparentWidgetBackground: View {
    let cornerRadius: CGFloat
    @AppStorage("glass.opacity") private var opacity = 0.16

    private var amount: Double { min(max(opacity, 0), 1) }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.black.opacity(amount))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(amount * 0.8), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
    }
}
