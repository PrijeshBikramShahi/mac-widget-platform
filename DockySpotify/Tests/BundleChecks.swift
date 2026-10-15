import AppKit

@main struct BundleChecks {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let bundle = Bundle(path: CommandLine.arguments[1])!
        try bundle.loadAndReturnError()
        guard let type = bundle.principalClass as? DockyWidgetPlugin.Type else {
            fatalError("Plugin class does not conform to host protocol")
        }
        let plugin = type.init()
        assert(plugin.identifier == "com.zyotis.widgion.spotify")
        assert(plugin.supportedSpanValues == [1, 2, 3, 4])
        assert(plugin.isExpandable && plugin.includesInPalette)
        for span in 1...4 {
            _ = plugin.makeView(cornerRadius: 18, renderedSpanValue: span, isWithinStack: false,
                                isExpanded: false, isExpandedPreviewOpen: false)
        }
        _ = plugin.makeView(cornerRadius: 24, renderedSpanValue: 2, isWithinStack: false,
                            isExpanded: true, isExpandedPreviewOpen: true)
        assert(bundle.url(forResource: "settings", withExtension: "json") != nil)
        print("Passed bundle loading, Obj-C protocol conformance, metadata, all tile spans, and expanded view creation.")
    }
}
