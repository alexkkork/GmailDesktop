import Foundation
import CoreBluetooth

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
    let rssi: Int
}

final class BluetoothManager: NSObject, ObservableObject {
    @Published var isPoweredOn: Bool = false
    @Published var isScanning: Bool = false
    @Published var devices: [DiscoveredDevice] = []
    @Published var connectedPeripheral: CBPeripheral?

    private var central: CBCentralManager!
    private var peripheralsById: [UUID: CBPeripheral] = [:]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard isPoweredOn else { return }
        isScanning = true
        devices.removeAll()
        peripheralsById.removeAll()
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScanning() {
        isScanning = false
        central.stopScan()
    }

    func connect(to device: DiscoveredDevice) {
        central.connect(device.peripheral, options: nil)
    }

    func disconnectCurrent() {
        if let p = connectedPeripheral {
            central.cancelPeripheralConnection(p)
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isPoweredOn = (central.state == .poweredOn)
        if isPoweredOn, isScanning {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Unknown"
        peripheralsById[peripheral.identifier] = peripheral
        peripheral.delegate = self
        let device = DiscoveredDevice(id: peripheral.identifier, name: name, peripheral: peripheral, rssi: RSSI.intValue)
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        } else {
            devices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
    }

    // MARK: - CBPeripheralDelegate (stubs to avoid API misuse warnings)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Discover characteristics for all services if needed
        guard error == nil else { return }
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) { }
}


