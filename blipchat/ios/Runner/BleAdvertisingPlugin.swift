import Flutter
import Foundation
import CoreBluetooth

class BleAdvertisingPlugin: NSObject, FlutterPlugin, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var channel: FlutterMethodChannel?
    private var peripheralManager: CBPeripheralManager?
    private var centralManager: CBCentralManager?
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    
    private var serviceUUID: CBUUID?
    private var characteristicUUID: CBUUID?
    private var isAdvertising = false
    private var connectedPeripherals: [CBPeripheral] = []
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "blipchat/ble_advertising", binaryMessenger: registrar.messenger())
        let instance = BleAdvertisingPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startAdvertising":
            guard let args = call.arguments as? [String: Any],
                  let serviceUuidString = args["serviceUuid"] as? String,
                  let characteristicUuidString = args["characteristicUuid"] as? String,
                  let deviceName = args["deviceName"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
                return
            }
            
            serviceUUID = CBUUID(string: serviceUuidString)
            characteristicUUID = CBUUID(string: characteristicUuidString)
            startAdvertising(deviceName: deviceName, result: result)
            
        case "stopAdvertising":
            stopAdvertising()
            result(true)
            
        case "sendMessage":
            guard let messageData = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_MESSAGE", message: "Invalid message data", details: nil))
                return
            }
            sendMessage(messageData: messageData, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startAdvertising(deviceName: String, result: @escaping FlutterResult) {
        guard peripheralManager?.state == .poweredOn else {
            result(FlutterError(code: "BLUETOOTH_UNAVAILABLE", message: "Bluetooth is not available", details: nil))
            return
        }
        
        guard let serviceUUID = serviceUUID,
              let characteristicUUID = characteristicUUID else {
            result(FlutterError(code: "INVALID_UUID", message: "Invalid UUIDs", details: nil))
            return
        }
        
        // Create service and characteristic
        service = CBMutableService(type: serviceUUID, primary: true)
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        service?.characteristics = [characteristic!]
        
        // Add service to peripheral manager
        peripheralManager?.add(service!)
        
        // Start advertising
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: deviceName
        ]
        
        // Start scanning for other devices
        if centralManager?.state == .poweredOn {
            centralManager?.scanForPeripherals(withServices: [serviceUUID], options: nil)
            print("Started scanning for peripherals")
        }
        
        peripheralManager?.startAdvertising(advertisementData)
        result(true)
    }
    
    private func stopAdvertising() {
        if isAdvertising {
            peripheralManager?.stopAdvertising()
            peripheralManager?.removeAllServices()
            centralManager?.stopScan()
            
            // Disconnect all peripherals
            connectedPeripherals.forEach { peripheral in
                centralManager?.cancelPeripheralConnection(peripheral)
            }
            connectedPeripherals.removeAll()
            
            isAdvertising = false
            channel?.invokeMethod("onAdvertisingStateChanged", arguments: false)
        }
    }
    
    private func sendMessage(messageData: [String: Any], result: @escaping FlutterResult) {
        // In a real implementation, you would send this to connected centrals
        print("Sending message: \(messageData)")
        result(true)
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("Peripheral manager state: \(peripheral.state.rawValue)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
            return
        }
        print("Service added successfully")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Error starting advertising: \(error.localizedDescription)")
            isAdvertising = false
            channel?.invokeMethod("onAdvertisingStateChanged", arguments: false)
        } else {
            print("Started advertising successfully")
            isAdvertising = true
            channel?.invokeMethod("onAdvertisingStateChanged", arguments: true)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid == characteristicUUID {
                if let data = request.value,
                   let messageJson = String(data: data, encoding: .utf8) {
                    // Forward message to Flutter
                    channel?.invokeMethod("onMessageReceived", arguments: messageJson)
                }
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central manager state: \(central.state.rawValue)")
        if central.state == .poweredOn && serviceUUID != nil {
            central.scanForPeripherals(withServices: [serviceUUID!], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        if !connectedPeripherals.contains(peripheral) {
            connectedPeripherals.append(peripheral)
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([serviceUUID!])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral")
        if let index = connectedPeripherals.firstIndex(of: peripheral) {
            connectedPeripherals.remove(at: index)
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID!], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Subscribed to characteristic notifications")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value,
              let messageJson = String(data: data, encoding: .utf8) else { return }
        
        print("Received message: \(messageJson)")
        channel?.invokeMethod("onMessageReceived", arguments: messageJson)
    }
}