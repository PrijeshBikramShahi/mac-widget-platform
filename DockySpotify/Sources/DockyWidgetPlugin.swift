import AppKit

// Cocoa ABI declared by Docky. Keep the explicit Obj-C name for host conformance.
@MainActor @objc(DockyWidgetPlugin) public protocol DockyWidgetPlugin: AnyObject {
    @objc init()
    var identifier: String { get }
    var displayName: String { get }
    var systemImageName: String { get }
    var defaultSpanValue: Int { get }
    var supportedSpanValues: [Int] { get }
    var expansionWidthTiles: Int { get }
    var expansionHeightTiles: Int { get }
    var isExpandable: Bool { get }
    var includesInPalette: Bool { get }
    var includesInSmartStack: Bool { get }
    @objc optional var author: String { get }
    @objc optional var version: String { get }
    @objc optional func makeSettingsView() -> NSView
    func makeView(cornerRadius: CGFloat, renderedSpanValue: Int, isWithinStack: Bool,
                  isExpanded: Bool, isExpandedPreviewOpen: Bool) -> NSView
    @objc optional func makeView(cornerRadius: CGFloat, renderedSpanValue: Int, isWithinStack: Bool,
                                isExpanded: Bool, isExpandedPreviewOpen: Bool,
                                configuration: [String: Any]) -> NSView
}
