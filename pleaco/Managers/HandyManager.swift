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
    
    private let baseURL = "https://www.handyfeeling.com/api/handy/v2"
    
    private init() {}
    
    func checkConnection(completion: @escaping (Bool) -> Void) {
        guard !connectionKey.isEmpty else {
            completion(false)
            return
        }
        
        // Simple connected status check
        sendRequest(path: "/connected") { result in
            switch result {
            case .success(let data):
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let connected = json["connected"] as? Bool {
                    completion(connected)
                } else {
                    completion(false)
                }
            case .failure:
                completion(false)
            }
        }
    }
    
    func startHamp() {
        // HAMP = Handy Alternating Motion Protocol (Speed control)
        sendRequest(path: "/mode", method: "PUT", params: ["userId": connectionKey, "mode": 1]) { _ in
            self.sendRequest(path: "/hamp/start", method: "PUT") { _ in }
        }
    }
    
    func stopMotion() {
        sendRequest(path: "/hamp/stop", method: "PUT") { _ in }
    }
    
    func setHampVelocity(speed: Double) {
        // Handy expects velocity 0-100
        let velocity = Int(max(0, min(100, speed)))
        sendRequest(path: "/hamp/velocity", method: "PUT", params: ["velocity": velocity]) { _ in }
    }
    
    func setDirectLevel(level: Double) {
        // For Oh. or HDSP (Handy Direct Sensor Protocol)
        // level 0-100
        let pos = Int(max(0, min(100, level)))
        sendRequest(path: "/hdsp/xpt", method: "PUT", params: ["position": pos]) { _ in }
    }
    
    func setSlideRange(min: Double, max: Double) {
        let pmin = Int(Swift.max(0, Swift.min(100, min)))
        let pmax = Int(Swift.max(0, Swift.min(100, max)))
        sendRequest(path: "/sldr", method: "PUT", params: ["min": pmin, "max": pmax]) { _ in }
    }
    
    private func sendRequest(path: String, method: String = "GET", params: [String: Any] = [:], completion: @escaping (Result<Data, Error>) -> Void = { _ in }) {
        guard !connectionKey.isEmpty else { return }
        
        var urlString = baseURL + path
        if method == "GET" {
            urlString += "?connectionKey=\(connectionKey)"
            for (key, value) in params {
                urlString += "&\(key)=\(value)"
            }
        }
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5.0 // 5 second timeout
        request.addValue(connectionKey, forHTTPHeaderField: "X-Connection-Key")
        
        if method != "GET" {
            var bodyParams = params
            bodyParams["connectionKey"] = connectionKey
            request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data {
                completion(.success(data))
            }
        }.resume()
    }
}
