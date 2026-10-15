import SwiftUI
import AppKit

/// Keep native slider tracking and accessibility while drawing a quieter track.
struct PlayerVolumeSlider: NSViewRepresentable {
    @Binding var value: Double
    let onEditingChanged: (Bool) -> Void
    let onCommit: () -> Void

    func makeNSView(context: Context) -> PlayerVolumeControl {
        let slider = PlayerVolumeControl()
        slider.cell = PlayerVolumeCell()
        slider.minValue = 0
        slider.maxValue = 100
        slider.isContinuous = true
        slider.controlSize = .mini
        slider.setAccessibilityLabel("Volume")
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        return slider
    }

    func updateNSView(_ slider: PlayerVolumeControl, context: Context) {
        context.coordinator.parent = self
        slider.doubleValue = value
        slider.onEditingChanged = onEditingChanged
        slider.onCommit = onCommit
        slider.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: PlayerVolumeSlider
        init(_ parent: PlayerVolumeSlider) { self.parent = parent }

        @objc func changed(_ slider: PlayerVolumeControl) {
            parent.value = slider.doubleValue
            // Keyboard and accessibility actions have no mouse-up to commit them.
            if !slider.trackingMouse { parent.onCommit() }
        }
    }
}

final class PlayerVolumeControl: NSSlider {
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onCommit: () -> Void = {}
    private(set) var trackingMouse = false
    private var hoverArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        (cell as? PlayerVolumeCell)?.hovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        (cell as? PlayerVolumeCell)?.hovering = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        trackingMouse = true
        onEditingChanged(true)
        super.mouseDown(with: event)
        trackingMouse = false
        onCommit()
        onEditingChanged(false)
        needsDisplay = true
    }
}

final class PlayerVolumeCell: NSSliderCell {
    var hovering = false

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = NSRect(x: rect.minX, y: rect.midY - 1, width: rect.width, height: 2)
        NSColor.white.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1, yRadius: 1).fill()
        let fraction = CGFloat(min(max((doubleValue - minValue) / max(maxValue - minValue, 1), 0), 1))
        let filled = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: 2)
        NSColor.white.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: filled, xRadius: 1, yRadius: 1).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        guard hovering || (controlView as? PlayerVolumeControl)?.trackingMouse == true
                || controlView?.window?.firstResponder === controlView else { return }
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: knobRect.midX - 3.5, y: knobRect.midY - 3.5,
                                  width: 7, height: 7)).fill()
    }
}
