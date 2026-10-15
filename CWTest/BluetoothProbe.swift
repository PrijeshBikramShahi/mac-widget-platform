import SwiftUI
import IOKit
import IOBluetooth

// Phase 1 Bluetooth battery probe. Tries three routes and reports what each returns.
// Add to the CWTest APP target first. Later we add it to the widget extension to test
// whether the widget can read the same data directly.

enum BluetoothProbe {

    static func run() -> String {
        var out = ""
        out += "== A: IORegistry scan for BatteryPercent ==\n"
        out += registryScan()
        out += "\n== B: com.apple.Bluetooth.plist DeviceCache ==\n"
        out += plistScan()
        out += "\n== C: IOBluetooth paired devices ==\n"
        out += pairedDevices()
        return out
    }

    // A: any IORegistry entry that exposes a BatteryPercent property
    // (usually Apple keyboards, mice and trackpads; AirPods may not appear here).
    private static func registryScan() -> String {
        var iter: io_iterator_t = 0
        let opts = IOOptionBits(kIORegistryIterateRecursively)
        guard IORegistryCreateIterator(kIOMainPortDefault, kIOServicePlane, opts, &iter) == KERN_SUCCESS else {
            return "Could not create registry iterator\n"
        }
        defer { IOObjectRelease(iter) }

        var result = ""
        var found = 0
        var entry = IOIteratorNext(iter)
        while entry != 0 {
            if let value = IORegistryEntryCreateCFProperty(entry, "BatteryPercent" as CFString,
                                                           kCFAllocatorDefault, 0)?.takeRetainedValue() {
                var nameBuf = [CChar](repeating: 0, count: 128)
                IORegistryEntryGetName(entry, &nameBuf)
                let product = IORegistryEntryCreateCFProperty(entry, "Product" as CFString,
                                                              kCFAllocatorDefault, 0)?.takeRetainedValue()
                result += "\(product ?? String(cString: nameBuf) as CFTypeRef): \(value)%\n"
                found += 1
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iter)
        }
        return found == 0 ? "No entries with BatteryPercent\n" : result
    }

    // B: cached device info in the system Bluetooth preferences file.
    private static func plistScan() -> String {
        let path = "/Library/Preferences/com.apple.Bluetooth.plist"
        guard let root = NSDictionary(contentsOfFile: path) else {
            return "Could not read \(path) (blocked by sandbox, or missing)\n"
        }
        guard let cache = root["DeviceCache"] as? [String: [String: Any]] else {
            return "File readable, but no DeviceCache key\n"
        }
        var result = ""
        for (_, dev) in cache {
            let name = dev["Name"] as? String ?? "(unnamed)"
            let keys = ["BatteryPercent", "BatteryPercentSingle", "BatteryPercentLeft",
                        "BatteryPercentRight", "BatteryPercentCase"]
            let levels = keys.compactMap { k in dev[k].map { "\(k)=\($0)" } }
            if !levels.isEmpty {
                result += "\(name): \(levels.joined(separator: ", "))\n"
            }
        }
        return result.isEmpty ? "DeviceCache readable, but no battery fields in it\n" : result
    }

    // C: confirms Bluetooth access works at all and lists devices.
    private static func pairedDevices() -> String {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return "No paired devices returned (permission or entitlement missing?)\n"
        }
        if devices.isEmpty { return "Paired device list is empty\n" }
        return devices.map { "\($0.nameOrAddress ?? "?"): connected=\($0.isConnected())" }
            .joined(separator: "\n") + "\n"
    }
}

struct ProbeView: View {
    @State private var output = "Connect your earbuds, then press Run probe."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Run probe") { output = BluetoothProbe.run() }
            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 360)
    }
}
