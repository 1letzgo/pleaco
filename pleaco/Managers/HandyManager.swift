//
//  HandyManager.swift
//  pleaco
//

import Foundation
import Combine

class HandyManager: ObservableObject {
    static let shared = HandyManager()

    var connectionKey: String = ""
    var deviceType: String = "The Handy"

    // API v3 Credentials
    private let baseURL = "https://www.handyfeeling.com/api/handy-rest/v3"
    private let apiKey = "Wu8AA1nDwSJl_P_pQiCdQkOnjNQjLVBL"

    private var currentTask: URLSessionDataTask?

    // Monotonically increasing token — incremented on every stop/start cycle.
    // Callbacks captured with a stale token are silently discarded to prevent
    // out-of-order API calls from leaving the device in a broken state.
    private var operationToken: Int = 0

    private init() {}

    /// Cancel all in-flight control requests and invalidate pending callbacks.
    func cancelPendingOperations() {
        operationToken &+= 1
        currentTask?.cancel()
        currentTask = nil
    }
    
    func checkConnection(completion: @escaping (Bool) -> Void) {
        guard !connectionKey.isEmpty else {
            completion(false)
            return
        }
        
        // v3 uses /connected to check online status. Response is {"result": {"connected": true}}
        sendRequest(path: "/connected") { result in
            switch result {
            case .success(let data):
                if let str = String(data: data, encoding: .utf8) {
                    NSLog("🔵 HandyManager (v3) /connected response: \(str)")
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultObj = json["result"] as? [String: Any],
                   let connected = resultObj["connected"] as? Bool {
                    completion(connected)
                } else {
                    NSLog("⚠️ HandyManager (v3): Failed to parse /connected response")
                    completion(false)
                }
            case .failure(let error):
                NSLog("❌ HandyManager (v3): /connected request failed: \(error)")
                completion(false)
            }
        }
    }
    
    func startHamp() {
        let token = operationToken
        if deviceType == "Oh." {
            NSLog("🔵 HandyManager (v3): Starting Oh. (mode 0, hvp)")
            sendRequest(path: "/mode", method: "PUT", params: ["mode": 0]) { _ in
                guard self.operationToken == token else { return }
                self.sendRequest(path: "/hvp/start", method: "PUT") { _ in }
            }
        } else {
            NSLog("🔵 HandyManager (v3): Starting The Handy (mode 0, hamp)")
            sendRequest(path: "/mode", method: "PUT", params: ["mode": 0]) { _ in
                guard self.operationToken == token else { return }
                self.sendRequest(path: "/hamp/start", method: "PUT") { _ in }
            }
        }
    }

    func startDirectMode(completion: @escaping (Bool) -> Void = { _ in }) {
        let token = operationToken
        NSLog("🔵 HandyManager (v3): Starting Direct Mode (mode 2, hdsp)")
        sendRequest(path: "/mode", method: "PUT", params: ["mode": 2]) { result in
            guard self.operationToken == token else { completion(false); return }
            switch result {
            case .success: completion(true)
            case .failure: completion(false)
            }
        }
    }
    
    func stopMotion() {
        // Cancel any pending velocity/level updates immediately
        currentTask?.cancel()
        currentTask = nil

        if deviceType == "Oh." {
            sendRequest(path: "/hvp/stop", method: "PUT") { _ in }
        } else {
            sendRequest(path: "/hamp/stop", method: "PUT") { _ in }
        }
    }
    
    func setHampVelocity(speed: Double) {
        // If speed is 0, we treat it as an explicit stop for maximum reliability
        if speed <= 0 {
            stopMotion()
            return
        }

        if deviceType == "Oh." {
            // HVP State uses amplitude 0.0 - 1.0. 
            // 75Hz is the default Sine resonance frequency for Oh! FW v4.
            let amplitude = max(0.0, min(1.0, speed / 100.0))
            sendRequest(path: "/hvp/state", method: "PUT", params: [
                "amplitude": amplitude,
                "frequency": 75, 
                "position": 50 // Standard mid-position for HVP
            ]) { _ in }
        } else {
            // HAMP Velocity uses 0.0 - 1.0 in v3
            let velocity = max(0.03, min(1.0, speed / 100.0)) // v3 likes a small floor for activity
            sendRequest(path: "/hamp/velocity", method: "PUT", params: ["velocity": velocity]) { _ in }
        }
    }
    
    func setDirectLevel(level: Double) {
        if deviceType == "Oh." {
            // Oh! has no slider, route FunScript position to vibration intensity
            setHampVelocity(speed: level)
        } else {
            // Standard Handy slider position — v3 expects Integer 0-100
            let pos = Int(max(0.0, min(100.0, level)))
            // Add velocity -1 for "immediate" response
            sendRequest(path: "/hdsp/xpt", method: "PUT", params: ["position": pos, "velocity": -1]) { _ in }
        }
    }
    
    func setSlideRange(min: Double, max: Double) {
        // "The Oh!" uses HVP (Vibration only), it does not have a slider stroke range.
        if deviceType == "Oh." {
            NSLog("🔵 HandyManager (v3): Skipping stroke range for Oh. (HVP device)")
            return
        }
        
        // v3 /slider/stroke expects min/max as 0.0 to 1.0 floats
        let pmin = Swift.max(0.0, Swift.min(1.0, min / 100.0))
        let pmax = Swift.max(0.0, Swift.min(1.0, max / 100.0))
        
        NSLog("🔵 HandyManager (v3): Setting stroke range min=\(pmin), max=\(pmax)")
        sendRequest(path: "/slider/stroke", method: "PUT", params: ["min": pmin, "max": pmax]) { result in
            switch result {
            case .success(let data):
                if let str = String(data: data, encoding: .utf8) {
                    NSLog("🔵 HandyManager (v3): /slider/stroke response: \(str)")
                }
            case .failure(let error):
                NSLog("❌ HandyManager (v3): /slider/stroke error: \(error)")
            }
        }
    }

    // MARK: - HSSP (Synchronized Script Playback)

    func uploadScript(data: Data, completion: @escaping (Result<(url: String, sha256: String), Error>) -> Void) {
        // Handy v3 upload endpoint: POST /hssp/upload
        NSLog("🔵 HandyManager (v3): Uploading FunScript...")
        
        let url = URL(string: "https://www.handyfeeling.com/api/handy-rest/v3/hssp/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(connectionKey, forHTTPHeaderField: "X-Connection-Key")
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        
        // Multipart form-data for the file
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"syncFile\"; filename=\"script.json\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "HandyManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let url = result["url"] as? String,
               let sha256 = result["sha256"] as? String {
                completion(.success((url: url, sha256: sha256)))
            } else {
                let errStr = String(data: data, encoding: .utf8) ?? "unknown"
                completion(.failure(NSError(domain: "HandyManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload failed: \(errStr)"])))
            }
        }.resume()
    }

    func setupHSSP(url: String, sha256: String, completion: @escaping (Bool) -> Void) {
        NSLog("🔵 HandyManager (v3): Setting up HSSP with URL: \(url) (SHA256: \(sha256))")
        sendRequest(path: "/hssp/setup", method: "PUT", params: ["url": url, "sha256": sha256]) { result in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                NSLog("❌ HandyManager (v3): HSSP setup failed: \(error)")
                completion(false)
            }
        }
    }

    func playHSSP(startTimeMs: Int, completion: @escaping (Bool) -> Void) {
        // We first need the server time for accurate sync
        getServerTime { serverTime in
            guard let serverTime = serverTime else {
                completion(false)
                return
            }
            
            NSLog("🔵 HandyManager (v3): Starting HSSP at \(startTimeMs)ms (ServerTime: \(serverTime))")
            self.sendRequest(path: "/hssp/play", method: "PUT", params: [
                "estimatedServerTime": serverTime,
                "startTime": startTimeMs
            ]) { result in
                switch result {
                case .success:
                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        }
    }

    func stopHSSP(completion: @escaping (Bool) -> Void = { _ in }) {
        let token = operationToken
        NSLog("🔵 HandyManager (v3): Stopping HSSP")
        sendRequest(path: "/hssp/stop", method: "PUT") { result in
            guard self.operationToken == token else { completion(false); return }
            switch result {
            case .success: completion(true)
            case .failure: completion(false)
            }
        }
    }

    func getServerTime(completion: @escaping (Int64?) -> Void) {
        sendRequest(path: "/servertime") { result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let resultObj = json["result"] as? [String: Any],
                   let serverTime = resultObj["serverTime"] as? Int64 {
                    completion(serverTime)
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let resultObj = json["result"] as? [String: Any],
                          let serverTime = resultObj["serverTime"] as? Double {
                    // Handle double just in case
                    completion(Int64(serverTime))
                } else {
                    completion(nil)
                }
            case .failure:
                completion(nil)
            }
        }
    }
    
    private func sendRequest(path: String, method: String = "GET", params: [String: Any] = [:], completion: @escaping (Result<Data, Error>) -> Void = { _ in }) {
        guard !connectionKey.isEmpty else { return }
        // No automatic cancellation for v3 state updates to prevent dropping requests at high frequency
        // URLSession handles the queue internally

        var urlString = baseURL + path
        if method == "GET" {
            // v3 recommends headers for connection key, so we keep URL clean unless forced
            var queryItems: [URLQueryItem] = []
            for (key, value) in params {
                queryItems.append(URLQueryItem(name: key, value: "\(value)"))
            }
            if !queryItems.isEmpty, var components = URLComponents(string: urlString) {
                components.queryItems = queryItems
                urlString = components.url?.absoluteString ?? urlString
            }
        }
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 7.0 
        
        // v3 Required Headers
        request.addValue(connectionKey, forHTTPHeaderField: "X-Connection-Key")
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        
        if method != "GET" && !params.isEmpty {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled {
                    return // Silent return on cancellation
                }
                NSLog("❌ HandyManager (v3): Network error on \(method) \(path) - \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown error"
                // Prevent extreme log spam for state updates, log once per failure payload
                if path != "/hvp/state" && path != "/hamp/velocity" {
                    NSLog("❌ HandyManager (v3): API error on \(method) \(path) [\(httpResponse.statusCode)] - \(errStr)")
                }
                let errorDesc = NSError(domain: "HandyManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errStr])
                completion(.failure(errorDesc))
                return
            }
            
            if let data = data {
                completion(.success(data))
            }
        }
        
        if path == "/hvp/state" || path == "/hamp/velocity" || path == "/hdsp/xpt" {
            self.currentTask = task
        }
        
        task.resume()
    }
}

