//
//  LoveSpouseManager.swift
//  pleaco
//
//  Controls LoveSpouse 2.4g toys via BLE Extended Advertising with 16-bit Service UUIDs.
//
//  PROTOCOL (reverse-engineered via PacketLogger iOS trace):
//
//  The iPhone acts as BLE Peripheral/Broadcaster. Toys scan for specific service UUIDs
//  and respond to the broadcast — both toys in range will react simultaneously.
//
//  Advertisement format (31 bytes, complete):
//    • Flags: 0x1A (LE General Discoverable + BR/EDR capable)
//    • 16-bit Service UUIDs (Complete list):
//        - 6 "command" UUIDs  (device/command data, positions 0-5)
//        - 7 "padding" UUIDs  (sequential: 0x0D0C → 0x1918, positions 6-12)
//
//  Captured from official LoveSpouse iOS app (PacketLogger trace 2025-02-25):
//    Command UUIDs (constant in observed traffic — intensity encoding TBD):
//      0x08F9  0x2349  0xCBAE  0xD1C1  0x156F  0x0B2C
//    Padding UUIDs (bytes equal their position index):
//      0x0D0C  0x0F0E  0x1110  0x1312  0x1514  0x1716  0x1918
//
//  Advertising intervals from official app:
//    Handle 0 (command): 30ms burst → 270ms normal
//    Handle 3 (passive): 2000ms always
//
//  TODO: Capture ADV data at 0% and 100% intensity to determine how
//        the 6 command UUIDs encode speed (which UUIDs change).
//

import Foundation
import CoreBluetooth
import Combine

class LoveSpouseManager: NSObject, ObservableObject {
    static let shared = LoveSpouseManager()

    // MARK: - Published State
    @Published var isConnected: Bool = false
    /// Currently active program (0 = stopped, 1–3 = speeds, 4–9 = patterns)
    @Published var activeProgram: Int = 0

    // MARK: - Private
    private var peripheralManager: CBPeripheralManager!
    private var burstTimer: Timer?
    private var isAdvertising = false
    
    // Extracted UUID pairs [UUID5, UUID6] mapped to 0-9
    // Order based on binary sequence 0x6E down to 0x66 observed in PacketLogger
    private let commandUUIDs: [Int: (String, String)] = [
        0: ("9C6E", "0B3D"), // Stop
        1: ("156F", "0B2C"), // Speed 1
        2: ("8E6C", "0B1E"), // Speed 2
        3: ("076D", "0B0F"), // Speed 3
        4: ("B86A", "0B7B"), // Pattern 1 (Button 4)
        5: ("316B", "0B6A"), // Pattern 2 (Button 5)
        6: ("AA68", "0B58"), // Pattern 3 (Button 6)
        7: ("2369", "0B49"), // Pattern 4 (Button 7)
        8: ("D466", "0BB1"), // Pattern 5 (Button 8)
        9: ("5D67", "0BA0")  // Pattern 6 (Button 9)
    ]

    private override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    /// Direct program selection. Sends a 500ms burst.
    func selectProgram(_ index: Int) {
        guard let uuids = commandUUIDs[index] else { return }
        activeProgram = index
        isConnected = true
        NSLog("🔵 LoveSpouseManager: Selecting program \(index)")
        
        startBurst(u5: uuids.0, u6: uuids.1)
    }

    /// Helper for legacy level control (0-100)
    func setLevel(_ level: Double) {
        let clamped = max(0, min(100, level))
        if clamped == 0 {
            stopAll()
        } else if clamped < 34 {
            selectProgram(1)
        } else if clamped < 67 {
            selectProgram(2)
        } else {
            selectProgram(3)
        }
    }

    func stopAll() {
        activeProgram = 0
        NSLog("🔵 LoveSpouseManager: Stop")
        selectProgram(0) // Send the explicit Stop command burst
    }

    func checkConnection(completion: @escaping (Bool) -> Void) {
        completion(peripheralManager.state == .poweredOn)
    }

    // MARK: - Private Burst Logic

    private var pendingBurst: DispatchWorkItem?

    private func startBurst(u5: String, u6: String) {
        // Cancel any pending delayed start — this is the key fix for rapid switching.
        // asyncAfter closures can't be cancelled, so stale commands would fire after
        // a new one was already sent, confusing the device into a stuck state.
        pendingBurst?.cancel()
        pendingBurst = nil

        // Stop current advertising immediately
        burstTimer?.invalidate()
        if isAdvertising {
            peripheralManager.stopAdvertising()
            isAdvertising = false
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !(self.pendingBurst?.isCancelled ?? true) else { return }

            let services: [CBUUID] = [
                CBUUID(string: "08F9"),
                CBUUID(string: "2349"),
                CBUUID(string: "CBAE"),
                CBUUID(string: "D1C1"),
                CBUUID(string: u5),
                CBUUID(string: u6),
                // Constant Padding
                CBUUID(string: "0D0C"), CBUUID(string: "0F0E"), CBUUID(string: "1110"),
                CBUUID(string: "1312"), CBUUID(string: "1514"), CBUUID(string: "1716"),
                CBUUID(string: "1918")
            ]

            self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: services])
            self.isAdvertising = true

            // Broadcast for 500ms then stop
            self.burstTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.peripheralManager.stopAdvertising()
                self?.isAdvertising = false
            }
        }

        pendingBurst = workItem
        // Small delay lets CoreBluetooth settle after stopAdvertising before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025, execute: workItem)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension LoveSpouseManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        isConnected = (peripheral.state == .poweredOn)
        NSLog("🔵 LoveSpouseManager: BLE State – \(peripheral.state.rawValue)")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            NSLog("🔵 LoveSpouseManager: ADV Failed – \(error.localizedDescription)")
        }
    }
}
