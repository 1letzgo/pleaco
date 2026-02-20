//
//  BackgroundAudioManager.swift
//  pleaco
//

import Foundation
import AVFoundation
import Combine

class BackgroundAudioManager: ObservableObject {
    static let shared = BackgroundAudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetoothHFP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session for background: \(error)")
        }
    }
    
    func startBackgroundAudio() {
        // Play a silent loop to keep the app alive in background if needed
        // Or just ensure the session is active.
        print("Background audio started")
    }
    
    func stopBackgroundAudio() {
        print("Background audio stopped")
    }
}
