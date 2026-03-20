//
//  RemoteManager.swift
//  pleaco
//

import Foundation
import CryptoKit
import Combine

enum RemoteState: Equatable {
    case disconnected
    case hosting
    case joining
    case connected
}

enum RemoteRole: String, CaseIterable, Identifiable {
    case sender = "Sender"
    case receiver = "Receiver"
    case dual = "Dual"

    var id: String { rawValue }
}

/// Message protocol (encrypted JSON):
struct RemotePayload: Codable {
    enum Command: String, Codable {
        case level = "L"
        case program = "P"
        case stop = "S"
        case handshake = "H"
    }
    
    let c: Command         // command
    var v: Double? = nil   // value (level)
    var i: Int? = nil      // index (program)
    var d: String? = nil   // device name/type
    var t: TimeInterval    // timestamp (for latency & watchdog)
}

class RemoteManager: ObservableObject {
    static let shared = RemoteManager()

    @Published var state: RemoteState = .disconnected
    @Published var roomCode: String = ""
    @Published var partnerConnected: Bool = false
    @Published var incomingLevel: Double = 0
    @Published var partnerDevice: String = ""
    @Published var partnerPing: Int = 0
    @Published var role: RemoteRole = .dual
    
    /// Triggered on every valid received relay payload to reset watchdog
    let signalPulse = PassthroughSubject<Void, Never>()
    @Published var serverAddress: String {
        didSet { UserDefaults.standard.set(serverAddress, forKey: "remoteServerAddress") }
    }

    /// True while applying a received remote command — prevents echo loop
    var isApplyingRemoteLevel: Bool = false

    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private var encryptionKey: SymmetricKey?
    private var lastSendTime: TimeInterval = 0
    private var heartbeatTimer: Timer?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        session = URLSession(configuration: config)
        serverAddress = UserDefaults.standard.string(forKey: "remoteServerAddress") ?? "wss://pleaco.shelf.am"
    }

    // MARK: - Host Session

    func hostSession() {
        guard state == .disconnected else { return }
        guard let url = URL(string: serverAddress) else {
            NSLog("🔔 RemoteManager: Invalid server URL: \(serverAddress)")
            return
        }

        DispatchQueue.main.async { self.state = .hosting }

        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()

        let msg: [String: Any] = ["type": "create"]
        sendJSON(msg)
        startHeartbeat()
    }

    // MARK: - Join Session

    func joinSession(code: String) {
        guard state == .disconnected else { return }
        guard let url = URL(string: serverAddress) else {
            NSLog("🔔 RemoteManager: Invalid server URL: \(serverAddress)")
            return
        }

        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        guard cleanCode.count == 6 else { return }

        DispatchQueue.main.async { self.state = .joining }

        encryptionKey = deriveKey(from: cleanCode)
        let roomHash = sha256Hex(cleanCode)

        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()

        let msg: [String: Any] = ["type": "join", "room": roomHash]
        sendJSON(msg)
        startHeartbeat()
    }

    // MARK: - Send Commands (encrypted)

    func sendLevel(_ level: Double) {
        sendPayload(RemotePayload(c: .level, v: level, t: Date().timeIntervalSince1970))
    }

    func sendProgram(_ index: Int) {
        sendPayload(RemotePayload(c: .program, i: index, t: Date().timeIntervalSince1970))
    }

    func sendStop() {
        sendPayload(RemotePayload(c: .stop, t: Date().timeIntervalSince1970))
    }
    
    func sendHandshake(device: String) {
        sendPayload(RemotePayload(c: .handshake, d: device, t: Date().timeIntervalSince1970))
    }

    private func sendPayload(_ payload: RemotePayload) {
        guard state == .connected, let key = encryptionKey else { return }
        if role == .receiver { return }
        
        // Throttle Level updates to 20Hz (50ms)
        let now = Date().timeIntervalSince1970
        if payload.c == .level && (now - lastSendTime < 0.05) {
            return
        }
        
        if payload.c == .level {
            lastSendTime = now
        }

        do {
            let data = try JSONEncoder().encode(payload)
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { return }

            let msg: [String: Any] = [
                "type": "relay",
                "payload": ["e": combined.base64EncodedString()]
            ]
            sendJSON(msg)
        } catch {
            NSLog("🔔 RemoteManager: Encrypt/Encode error: \(error)")
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        encryptionKey = nil

        DispatchQueue.main.async {
            self.state = .disconnected
            self.roomCode = ""
            self.partnerConnected = false
            self.incomingLevel = 0
            DeviceManager.shared.stop()
        }
    }

    // MARK: - Private: WebSocket

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { error in
            if let error = error {
                NSLog("🔔 RemoteManager: Send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self?.handleMessage(text)
                }
                self?.receiveMessage()
            case .failure(let error):
                NSLog("🔔 RemoteManager: Connection lost: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.state = .disconnected
                    self?.partnerConnected = false
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "code":
            if let code = json["code"] as? String {
                encryptionKey = deriveKey(from: code)
                DispatchQueue.main.async {
                    self.roomCode = code
                }
            }

        case "joined":
            DispatchQueue.main.async {
                self.partnerConnected = true
                self.state = .connected
            }

        case "relay":
            handleRelayPayload(json)

        case "partner_left":
            DispatchQueue.main.async {
                self.partnerConnected = false
                self.state = .disconnected
                self.roomCode = ""
                self.incomingLevel = 0
            }
            disconnect()

        case "error":
            let msg = json["msg"] as? String ?? "Unknown error"
            NSLog("🔔 RemoteManager: Server error: \(msg)")
            disconnect()

        default:
            break
        }
    }

    private func handleRelayPayload(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let encrypted = payload["e"] as? String,
              let key = encryptionKey else { return }

        guard let combined = Data(base64Encoded: encrypted) else { return }

        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(box, using: key)
            let payload = try JSONDecoder().decode(RemotePayload.self, from: decrypted)

            DispatchQueue.main.async {
                // Calculate latency (ping)
                let rtt = Date().timeIntervalSince1970 - payload.t
                self.partnerPing = Int(rtt * 1000)
                self.signalPulse.send()
                self.applyRemotePayload(payload)
            }
        } catch {
            NSLog("🔔 RemoteManager: Decrypt/Decode error: \(error)")
        }
    }

    private func applyRemotePayload(_ payload: RemotePayload) {
        // Sender role does not receive/apply commands
        if role == .sender { return }
        
        let dm = DeviceManager.shared
        isApplyingRemoteLevel = true

        switch payload.c {
        case .level:
            if let level = payload.v {
                incomingLevel = level
                if !dm.isPlaying {
                    dm.isPlaying = true
                }
                dm.setLevel(level)
            }
            
        case .program:
            if let index = payload.i {
                NSLog("🔔 RemoteManager: Received program \(index)")
                dm.selectLoveSpouseProgram(index)
            }
            
        case .stop:
            NSLog("🔔 RemoteManager: Received stop")
            dm.stop()
            
        case .handshake:
            if let device = payload.d {
                NSLog("🔔 RemoteManager: Partner handshake: \(device)")
                self.partnerDevice = device
            }
        }

        isApplyingRemoteLevel = false
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendJSON(["type": "ping"])
        }
    }

    // MARK: - Crypto

    private func deriveKey(from code: String) -> SymmetricKey {
        let inputKey = SymmetricKey(data: Data(code.utf8))
        let salt = Data("pleaco".utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data(),
            outputByteCount: 32
        )
    }

    private func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
