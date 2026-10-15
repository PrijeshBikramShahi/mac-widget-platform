import SwiftUI
import IOKit
import CoreBluetooth
import Combine
// Bluetooth probe v2. Keep BluetoothProbe.swift in the project as well.
// In ContentView, show ProbeView2() instead of ProbeView().

enum BluetoothProbe2 {

    static func run() -> String {
        var out = "== A2: registry properties with 'batt' in the name ==\n"
        out += registryBatteryKeys()
        out += "\n== B2: Bluetooth plist keys and battery-like fields ==\n"
        out += plistDump()
        return out
    }

    private static func registryBatteryKeys() -> String {
        var iter: io_iterator_t = 0
        guard IORegistryCreateIterator(kIOMainPortDefault, kIOServicePlane,
                                       IOOptionBits(kIORegistryIterateRecursively), &iter) == KERN_SUCCESS else {
            return "Could not create registry iterator\n"
        }
        defer { IOObjectRelease(iter) }

        var lines: [String] = []
        var entry = IOIteratorNext(iter)
        while entry != 0 {
            var unmanaged: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = unmanaged?.takeRetainedValue() as? [String: Any] {
                var nameBuf = [CChar](repeating: 0, count: 128)
                IORegistryEntryGetName(entry, &nameBuf)
                let name = String(cString: nameBuf)
                for (k, v) in props where k.lowercased().contains("batt") {
                    lines.append("\(name): \(k) = \(v)")
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iter)
        }
        if lines.isEmpty { return "None found\n" }
        return lines.prefix(40).joined(separator: "\n") + (lines.count > 40 ? "\n... (\(lines.count) total)\n" : "\n")
    }

    private static func plistDump() -> String {
        let path = "/Library/Preferences/com.apple.Bluetooth.plist"
        guard let root = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return "Could not read \(path)\n"
        }
        var out = "Top-level keys: \(root.keys.sorted().joined(separator: ", "))\n"
        var hits: [String] = []
        findBattery(root, path: "", depth: 0, into: &hits)
        out += hits.isEmpty ? "No battery-like keys anywhere in the file\n"
                            : hits.prefix(30).joined(separator: "\n") + "\n"
        return out
    }

    private static func findBattery(_ node: Any, path: String, depth: Int, into out: inout [String]) {
        guard depth < 6 else { return }
        if let d = node as? [String: Any] {
            for (k, v) in d {
                if k.lowercased().contains("batt") { out.append("\(path)/\(k) = \(v)") }
                findBattery(v, path: path + "/" + k, depth: depth + 1, into: &out)
            }
        } else if let a = node as? [Any] {
            for (i, v) in a.enumerated() {
                findBattery(v, path: "\(path)[\(i)]", depth: depth + 1, into: &out)
            }
        }
    }
}

// D: standard Bluetooth LE Battery Service (0x180F), characteristic 0x2A19.
final class BLEBatteryProbe: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var log = ""
    private var central: CBCentralManager?
    private var peripherals: [CBPeripheral] = []
    private let batteryService = CBUUID(string: "180F")
    private let batteryLevel = CBUUID(string: "2A19")

    func start() {
        log = ""
        peripherals = []
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func append(_ s: String) { log += s + "\n" }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        guard c.state == .poweredOn else {
            append("Bluetooth state = \(c.state.rawValue) (5 means ready; 3 means permission denied)")
            return
        }
        peripherals = c.retrieveConnectedPeripherals(withServices: [batteryService])
        if peripherals.isEmpty {
            append("No connected device exposes the BLE Battery Service")
            return
        }
        for p in peripherals {
            append("Found \(p.name ?? "unnamed"), connecting...")
            p.delegate = self
            c.connect(p)
        }
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([batteryService])
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        append("Connect failed for \(p.name ?? "?"): \(error?.localizedDescription ?? "unknown")")
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] { p.discoverCharacteristics([batteryLevel], for: s) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for c in s.characteristics ?? [] { p.readValue(for: c) }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let level = c.value?.first {
            append("\(p.name ?? "unnamed"): battery \(level)%")
        } else {
            append("\(p.name ?? "unnamed"): read failed \(error?.localizedDescription ?? "")")
        }
    }
}

struct ProbeView2: View {
    @StateObject private var ble = BLEBatteryProbe()
    @State private var syncOutput = "Connect your earbuds, then press Run probe."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Run probe") {
                syncOutput = BluetoothProbe2.run()
                ble.start()
            }
            ScrollView {
                Text(syncOutput + "\n== D: BLE Battery Service ==\n" + ble.log)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 400)
    }
}
