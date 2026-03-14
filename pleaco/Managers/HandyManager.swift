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
    
    private init() {}
    
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
        if deviceType == "Oh." {
            NSLog("🔵 HandyManager (v3): Starting Oh. (mode 0, hvp)")
            // API v3 has no mode 8. HVP works alongside mode 0 (HAMP) or default mode.
            sendRequest(path: "/mode2", method: "PUT", params: ["mode": 0]) { _ in
                self.sendRequest(path: "/hvp/start", method: "PUT") { _ in }
            }
        } else {
            // mode 0 = HAMP for The Handy
            NSLog("🔵 HandyManager (v3): Starting The Handy (mode 0, hamp)")
            sendRequest(path: "/mode2", method: "PUT", params: ["mode": 0]) { _ in
                self.sendRequest(path: "/hamp/start", method: "PUT") { _ in }
            }
        }
    }

    func startDirectMode() {
        // mode 2 = HDSP (Direct Streaming) for The Handy / Oh.
        NSLog("🔵 HandyManager (v3): Starting Direct Mode (mode 2, hdsp)")
        sendRequest(path: "/mode2", method: "PUT", params: ["mode": 2]) { _ in }
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
        let pos = Int(max(0, min(100, level)))
        sendRequest(path: "/hdsp/xpt", method: "PUT", params: ["position": pos]) { _ in }
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
    
    private func sendRequest(path: String, method: String = "GET", params: [String: Any] = [:], completion: @escaping (Result<Data, Error>) -> Void = { _ in }) {
        guard !connectionKey.isEmpty else { return }
        
        // Cancel pending state updates if a new one arrives (only for frequent update paths)
        if path == "/hvp/state" || path == "/hamp/velocity" || path == "/hdsp/xpt" {
            currentTask?.cancel()
        }

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

