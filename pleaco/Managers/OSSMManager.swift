//
//  OSSMManager.swift
//  pleaco
//
//  Controls OSSM hardware via BLE.
//

import Foundation
import CoreBluetooth
import Combine

class OSSMManager: NSObject, ObservableObject {
    static let shared = OSSMManager()

    // MARK: - Constants
    private let serviceUUID = CBUUID(string: "522b443a-4f53-534d-0001-420badbabe69")
    private let commandCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-1000-420badbabe69")
    private let stateCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-2000-420badbabe69")
    private let patternCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-3000-420badbabe69")
    private let patternDescriptionCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-3010-420badbabe69")
    private let commandKnobCharacteristicUUID = CBUUID(string: "522b443a-4f53-534d-1010-420badbabe69")

    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var isReady: Bool = false
    @Published var deviceState: String = "idle"
    @Published var availablePatterns: [String] = []
    @Published var patternDescriptions: [Int: String] = [:]
    
    // Stroker mode: syncs depth and stroke length
    @Published var strokerMode: Bool = false

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var descriptionCharacteristic: CBCharacteristic?
    private var knobCharacteristic: CBCharacteristic?
    
    private var connectionCompletion: ((Bool) -> Void)?
    private var lastState: String = ""
    private var lastRequestedDescriptionIndex: Int?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    func startScanning(completion: @escaping (Bool) -> Void) {
        self.connectionCompletion = completion
        
        guard centralManager.state == .poweredOn else {
            completion(false)
            return
        }

        NSLog("🔵 OSSMManager: Starting scan for OSSM...")
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        
        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if let self = self, self.centralManager.isScanning {
                self.centralManager.stopScan()
                if !self.isConnected {
                    NSLog("🔵 OSSMManager: Scan timeout")
                    self.connectionCompletion?(false)
                    self.connectionCompletion = nil
                }
            }
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetState()
    }

    func stop() {
        // go:idle handles motor stop and state transition
        sendCommand("go:idle")
    }

    func setLevel(_ level: Double) {
        let speed = Int(max(0, min(100, level)))
        sendCommand("set:speed:\(speed)")
        
        // Only trigger strokeEngine mode if we aren't already there and speed > 0
        if speed > 0 && deviceState != "strokeEngine" {
            sendCommand("go:strokeEngine")
        }
    }

    func setDepth(_ depth: Double, syncStroke: Bool = true) {
        let val = Int(max(0, min(100, depth)))
        sendCommand("set:depth:\(val)")
        
        if strokerMode && syncStroke {
            // derivedStroke = Math.round((value - 50) * 2)
            let derivedStroke = max(0.0, min(100.0, Double((val - 50) * 2)))
            setStroke(derivedStroke, syncDepth: false)
        }
    }

    func setStroke(_ stroke: Double, syncDepth: Bool = true) {
        let val = Int(max(0, min(100, stroke)))
        sendCommand("set:stroke:\(val)")
        
        if strokerMode && syncDepth {
            // derivedDepth = Math.round((value / 2) + 50)
            let derivedDepth = max(0.0, min(100.0, Double(val / 2 + 50)))
            setDepth(derivedDepth, syncStroke: false)
        }
    }

    func setSensation(_ sensation: Double) {
        let val = Int(max(0, min(100, sensation)))
        sendCommand("set:sensation:\(val)")
    }

    func setPattern(_ patternIndex: Int) {
        let val = max(0, min(6, patternIndex))
        sendCommand("set:pattern:\(val)")
        
        // Reset sensation to 50 when pattern changes (per OSSM.svelte logic)
        setSensation(50)
        
        // Fetch description if missing
        if patternDescriptions[val] == nil {
            lastRequestedDescriptionIndex = val
            fetchDescription(for: val)
        }
    }
    
    func fetchDescription(for index: Int) {
        guard let characteristic = descriptionCharacteristic, let peripheral = peripheral else { return }
        lastRequestedDescriptionIndex = index
        let indexString = String(index)
        if let data = indexString.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            // After writing, we read the result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    // MARK: - Private Methods

    private func sendCommand(_ command: String) {
        NSLog("🔵 OSSMManager: Request to send -> \(command) (Ready: \(isReady))")
        guard let peripheral = peripheral,
              let characteristic = commandCharacteristic,
              isReady else { return }

        if let data = command.data(using: .utf8) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            NSLog("🔵 OSSMManager: Sent command -> \(command)")
        }
    }

    private func resetState() {
        peripheral = nil
        commandCharacteristic = nil
        isConnected = false
        isReady = false
        deviceState = "idle"
        centralManager.stopScan()
    }
}

// MARK: - CBCentralManagerDelegate

extension OSSMManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            resetState()
        }
        NSLog("🔵 OSSMManager: Central state updated to \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        NSLog("🔵 OSSMManager: Discovered OSSM: \(peripheral.name ?? "Unknown")")
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("🔵 OSSMManager: Connected to peripheral")
        isConnected = true
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("🔵 OSSMManager: Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        resetState()
        connectionCompletion?(false)
        connectionCompletion = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("🔵 OSSMManager: Disconnected")
        resetState()
    }
}

// MARK: - CBPeripheralDelegate

extension OSSMManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([
                commandCharacteristicUUID,
                stateCharacteristicUUID,
                patternCharacteristicUUID,
                patternDescriptionCharacteristicUUID,
                commandKnobCharacteristicUUID
            ], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == commandCharacteristicUUID {
                self.commandCharacteristic = characteristic
                self.isReady = true
                NSLog("🔵 OSSMManager: Command characteristic ready")
                connectionCompletion?(true)
                connectionCompletion = nil
            } else if characteristic.uuid == stateCharacteristicUUID {
                // Subscribe to state updates
                peripheral.setNotifyValue(true, for: characteristic)
                NSLog("🔵 OSSMManager: Subscribed to state updates")
            } else if characteristic.uuid == patternCharacteristicUUID {
                // Read pattern list once
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == patternDescriptionCharacteristicUUID {
                self.descriptionCharacteristic = characteristic
                NSLog("🔵 OSSMManager: Description characteristic ready")
            } else if characteristic.uuid == commandKnobCharacteristicUUID {
                self.knobCharacteristic = characteristic
                // set bluetooth to have full control of speed knob (send "false")
                if let data = "false".data(using: .utf8) {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == stateCharacteristicUUID {
            // Handle JSON state: { "state": "strokeEngine", "speed": 80, ... }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? String {
                DispatchQueue.main.async {
                    self.deviceState = state
                    // We could also sync sliders here if we wanted to prevent fighting with the user's thumb
                    // For now, just logging for diagnostics
                    if state != self.lastState {
                        NSLog("🔵 OSSMManager: Device State -> \(state)")
                        self.lastState = state
                    }
                }
            }
        } else if characteristic.uuid == patternCharacteristicUUID {
            // Handle Pattern List JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let names = json.compactMap { $0["name"] as? String }
                DispatchQueue.main.async {
                    self.availablePatterns = names
                    NSLog("🔵 OSSMManager: Discovered \(names.count) patterns")
                }
            }
        } else if characteristic.uuid == patternDescriptionCharacteristicUUID {
            if let description = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if let index = self.lastRequestedDescriptionIndex {
                        self.patternDescriptions[index] = description
                        NSLog("🔵 OSSMManager: Pattern [\(index)] Description -> \(description)")
                        self.lastRequestedDescriptionIndex = nil
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("🔵 OSSMManager: Write error: \(error.localizedDescription)")
        }
    }
}
