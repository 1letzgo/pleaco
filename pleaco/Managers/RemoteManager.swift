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
    case controller = "Controller"
    case receiver = "Receiver"
    case bidirectional = "Bidirectional"

    var id: String { rawValue }
}

/// Message protocol (encrypted plaintext):
/// - "L80.0"  → level (0-100)
/// - "P3"     → select LoveSpouse program (1-9)
/// - "S"      → stop playback
class RemoteManager: ObservableObject {
    static let shared = RemoteManager()

    @Published var state: RemoteState = .disconnected
    @Published var roomCode: String = ""
    @Published var partnerConnected: Bool = false
    @Published var incomingLevel: Double = 0
    @Published var role: RemoteRole = .bidirectional
    @Published var serverAddress: String {
        didSet { UserDefaults.standard.set(serverAddress, forKey: "remoteServerAddress") }
    }

    /// True while applying a received remote command — prevents echo loop
    var isApplyingRemoteLevel: Bool = false

    private var webSocket: URLSessionWebSocketTask?
    private let session: URLSession
    private var encryptionKey: SymmetricKey?
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
        sendEncrypted(String(format: "L%.1f", level))
    }

    func sendProgram(_ index: Int) {
        sendEncrypted("P\(index)")
    }

    func sendStop() {
        sendEncrypted("S")
    }

    private func sendEncrypted(_ plaintext: String) {
        guard state == .connected, let key = encryptionKey else { return }
        guard let data = plaintext.data(using: .utf8) else { return }

        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { return }

            let msg: [String: Any] = [
                "type": "relay",
                "payload": ["e": combined.base64EncodedString()]
            ]
            sendJSON(msg)
        } catch {
            NSLog("🔔 RemoteManager: Encrypt error: \(error)")
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
            guard let command = String(data: decrypted, encoding: .utf8) else { return }

            DispatchQueue.main.async {
                self.applyRemoteCommand(command)
            }
        } catch {
            NSLog("🔔 RemoteManager: Decrypt error: \(error)")
        }
    }

    private func applyRemoteCommand(_ command: String) {
        let dm = DeviceManager.shared
        isApplyingRemoteLevel = true

        if command.hasPrefix("L") {
            // Level command: "L80.0"
            guard let level = Double(command.dropFirst()) else {
                isApplyingRemoteLevel = false
                return
            }
            incomingLevel = level
            if !dm.isManualControlActive {
                dm.applyManualControl()
            }
            dm.setLevel(level)

        } else if command.hasPrefix("P") {
            // Program command: "P3"
            guard let index = Int(command.dropFirst()) else {
                isApplyingRemoteLevel = false
                return
            }
            NSLog("🔔 RemoteManager: Received program \(index)")
            dm.selectLoveSpouseProgram(index)

        } else if command == "S" {
            // Stop command
            NSLog("🔔 RemoteManager: Received stop")
            dm.stop()
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
        let inputKey = SymmetricKey(data: code.data(using: .utf8)!)
        let salt = "pleaco".data(using: .utf8)!
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data(),
            outputByteCount: 32
        )
    }

    private func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: input.data(using: .utf8)!)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
