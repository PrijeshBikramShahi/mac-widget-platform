import AppKit
import SwiftUI
import Combine

/// Geometry is independent of windows so snapping can be checked without moving the desktop.
enum LayoutSnap {
    static let threshold: CGFloat = 10

    static func origin(for frame: CGRect, near neighbors: [CGRect], visibleFrame: CGRect,
                       freely: Bool) -> CGPoint {
        guard !freely else { return frame.origin }
        let gap = WidgetGrid.gap
        var xs = [visibleFrame.minX + gap, visibleFrame.maxX - gap - frame.width]
        var ys = [visibleFrame.minY + gap, visibleFrame.maxY - gap - frame.height]
        for other in neighbors {
            // Only attract nearby rows/columns, never unrelated windows across the screen.
            if frame.maxY >= other.minY - gap - threshold && frame.minY <= other.maxY + gap + threshold {
                xs += [other.minX, other.maxX - frame.width,
                       other.maxX + gap, other.minX - gap - frame.width]
            }
            if frame.maxX >= other.minX - gap - threshold && frame.minX <= other.maxX + gap + threshold {
                ys += [other.minY, other.maxY - frame.height,
                       other.maxY + gap, other.minY - gap - frame.height]
            }
        }
        func closest(_ value: CGFloat, _ candidates: [CGFloat]) -> CGFloat {
            guard let best = candidates.min(by: { abs($0 - value) < abs($1 - value) }),
                  abs(best - value) <= threshold else { return value }
            return best
        }
        return CGPoint(x: closest(frame.minX, xs), y: closest(frame.minY, ys))
    }
}

@MainActor
final class LayoutController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = LayoutController()
    @Published var isEditing = false {
        didSet {
            for panel in panels.allObjects {
                panel.isMovable = isEditing
                panel.isMovableByWindowBackground = isEditing
            }
        }
    }
    private let panels = NSHashTable<NSPanel>.weakObjects()
    private var adjusting = false

    func register(_ panel: NSPanel) {
        panels.add(panel)
        panel.delegate = self
        panel.isMovable = isEditing
        panel.isMovableByWindowBackground = isEditing
    }

    func windowDidMove(_ notification: Notification) {
        guard isEditing, !adjusting, NSEvent.pressedMouseButtons & 1 != 0,
              let panel = notification.object as? LayoutPanel,
              let start = panel.dragStart,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
                ?? panel.screen else { return }
        // Always use the pointer's original offset, so snapping never accumulates drift.
        let mouse = NSEvent.mouseLocation
        let proposed = CGRect(origin: CGPoint(x: start.origin.x + mouse.x - start.mouse.x,
                                               y: start.origin.y + mouse.y - start.mouse.y),
                              size: panel.frame.size)
        let neighbors = panels.allObjects.filter { $0 !== panel && $0.isVisible }
            .map(\.frame).filter { $0.intersects(screen.frame) }
        let origin = LayoutSnap.origin(for: proposed, near: neighbors, visibleFrame: screen.visibleFrame,
                                       freely: NSEvent.modifierFlags.contains(.option))
        guard panel.frame.origin != origin else { return }
        adjusting = true
        panel.setFrameOrigin(origin)
        adjusting = false
    }
}

final class LayoutPanel: NSPanel {
    var dragStart: (origin: CGPoint, mouse: CGPoint)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            dragStart = (frame.origin, NSEvent.mouseLocation)
        }
        super.sendEvent(event)
        if event.type == .leftMouseUp {
            dragStart = nil
            if !frameAutosaveName.isEmpty { saveFrame(usingName: frameAutosaveName) }
        }
    }
}

struct LayoutOutline: View {
    @ObservedObject private var layout = LayoutController.shared

    var body: some View {
        RoundedRectangle(cornerRadius: WidgetGrid.cornerRadius, style: .continuous)
            .strokeBorder(.white.opacity(layout.isEditing ? 0.65 : 0),
                          style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .padding(1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
