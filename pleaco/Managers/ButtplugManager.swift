//
//  ButtplugManager.swift
//  pleaco
//

import Foundation
import Combine

class ButtplugManager: ObservableObject {
    static let shared = ButtplugManager()
    
    @Published var isConnected = false
    var serverAddress: String = "ws://127.0.0.1:12345"
    
    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        session = URLSession(configuration: config)
    }
    
    func connect(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: serverAddress) else {
            completion(false)
            return
        }
        
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        // Simple ping-like check for Buttplug.io
        // In a real impl, we'd send a ServerInfo message
        isConnected = true
        completion(true)
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocket?.cancel(with: .normalClosure, reason: nil)
        isConnected = false
    }
    
    func setLevel(_ level: Double) {
        // level 0-100 -> buttplug 0.0-1.0
        let scalar = level / 100.0
        let msg = """
        [{"VibrateCmd": {"Id": 1, "DeviceIndex": 0, "Speeds": [{"Index": 0, "Speed": \(scalar)}]}}]
        """
        sendMessage(msg)
    }
    
    func stopAllDevices() {
        let msg = """
        [{"StopDeviceCmd": {"Id": 1, "DeviceIndex": 0}}]
        """
        sendMessage(msg)
    }
    
    private func sendMessage(_ text: String) {
        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("Buttplug send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Buttplug received: \(text)")
                default: break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("Buttplug disconnected: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
}
