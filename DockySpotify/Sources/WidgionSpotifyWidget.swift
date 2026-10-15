import AppKit
import SwiftUI

@MainActor @objc(WidgionSpotifyWidget)
public final class WidgionSpotifyWidget: NSObject, DockyWidgetPlugin {
    // Shared across dock tiles and previews, but lazy so discovery itself sends no Apple Events.
    private lazy var service = SpotifyService(observePlayback: false)
    public override init() { super.init() }
    public var identifier: String { "com.zyotis.widgion.spotify" }
    public var displayName: String { "Widgion Spotify" }
    public var systemImageName: String { "music.note" }
    public var defaultSpanValue: Int { 2 }
    public var supportedSpanValues: [Int] { [1, 2, 3, 4] }
    public var expansionWidthTiles: Int { 5 }
    public var expansionHeightTiles: Int { 2 }
    public var isExpandable: Bool { true }
    public var includesInPalette: Bool { true }
    public var includesInSmartStack: Bool { true }
    public var author: String { "Widgion" }
    public var version: String { "1.0.0" }

    public func makeView(cornerRadius: CGFloat, renderedSpanValue: Int, isWithinStack: Bool,
                         isExpanded: Bool, isExpandedPreviewOpen: Bool) -> NSView {
        makeView(cornerRadius: cornerRadius, renderedSpanValue: renderedSpanValue,
                 isWithinStack: isWithinStack, isExpanded: isExpanded,
                 isExpandedPreviewOpen: isExpandedPreviewOpen, configuration: [:])
    }

    public func makeView(cornerRadius: CGFloat, renderedSpanValue: Int, isWithinStack: Bool,
                         isExpanded: Bool, isExpandedPreviewOpen: Bool,
                         configuration: [String: Any]) -> NSView {
        let host = SpotifyWidgetHostingView(rootView: DockySpotifyView(service: service,
            cornerRadius: cornerRadius, span: renderedSpanValue, expanded: isExpanded,
            artworkBackground: (configuration["artworkBackground"] as? Bool) ?? true))
        host.sizingOptions = []
        return host
    }
}

private final class SpotifyWidgetHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
