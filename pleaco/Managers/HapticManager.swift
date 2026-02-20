//
//  HapticManager.swift
//  pleaco
//

import Foundation
#if os(iOS)
import UIKit
#endif
import CoreHaptics
import Combine
import AudioToolbox
import AVFoundation

class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    @Published var isSupported = false
    @Published var isEngineRunning = false
    @Published var engineError: String?
    
    private init() {
        NSLog("🔔 HapticManager: Initializing")
        setupEngine()
    }
    
    func setupEngine() {
        NSLog("🔔 HapticManager: setupEngine() called")
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        NSLog("🔔 HapticManager: supportsHaptics: \(capabilities.supportsHaptics), supportsAudio: \(capabilities.supportsAudio)")
        guard capabilities.supportsHaptics else {
            NSLog("🔔 HapticManager: Hardware does not support haptics")
            return
        }
        isSupported = true

        #if os(iOS)
        // Ensure AVAudioSession is ready for haptics
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            NSLog("🔔 HapticManager: AVAudioSession configured for playback/haptics")
        } catch {
            NSLog("🔔 HapticManager: Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
        #endif

        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = false 
            
            engine?.stoppedHandler = { [weak self] reason in
                NSLog("🔔 HapticManager: Engine Stopped. Reason: \(reason.rawValue)")
                DispatchQueue.main.async {
                    self?.isEngineRunning = false
                    self?.continuousPlayer = nil
                    if reason != .audioSessionInterrupt && reason != .applicationSuspended {
                        self?.engineError = "Engine stopped: \(reason.rawValue)"
                    }
                }
            }

            engine?.resetHandler = { [weak self] in
                NSLog("🔔 HapticManager: Engine Reset Handler called")
                DispatchQueue.main.async {
                    self?.continuousPlayer = nil
                    do {
                        try self?.engine?.start()
                        self?.isEngineRunning = true
                        NSLog("🔔 HapticManager: Engine restarted after reset")
                    } catch {
                        NSLog("🔔 HapticManager: Failed to restart engine after reset: \(error)")
                    }
                }
            }
            
            try engine?.start()
            isEngineRunning = true
            NSLog("🔔 HapticManager: Engine started successfully during setup")
        } catch {
            engineError = error.localizedDescription
            NSLog("🔔 HapticManager: Engine setup failed: \(error.localizedDescription)")
        }
    }
    
    func playUltraTest() {
        NSLog("🔔 HapticManager: playUltraTest (AudioServices Vibrate)")
        #if os(iOS)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #else
        NSLog("🔔 HapticManager: Ultra test skipped (not iOS)")
        #endif
    }
    
    func playImpactTest() {
        NSLog("🔔 HapticManager: playImpactTest (UIImpactFeedback)")
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        #else
        NSLog("🔔 HapticManager: Simple impact skipped (not iOS)")
        #endif
    }
    
    func playTestHaptic() {
        NSLog("🔔 HapticManager: playTestHaptic (Transient Event)")
        guard isSupported else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            try engine?.start()
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
            NSLog("🔔 HapticManager: Test haptic (transient) played")
        } catch {
            NSLog("🔔 HapticManager: Test haptic failed: \(error)")
        }
    }
    
    private func createContinuousPlayer() {
        guard let engine = engine else { return }

        // CoreHaptics hapticContinuous events have a max duration of 30 seconds.
        // We use loopEnabled = true on the advanced player to keep it running.
        // IMPORTANT: Baseline intensity must be 1.0 for dynamic control to work properly.
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 30)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            continuousPlayer?.loopEnabled = true
            continuousPlayer?.playbackRate = 1.0
            NSLog("🔔 HapticManager: Continuous player created and loopEnabled=true")
        } catch {
            NSLog("🔔 HapticManager: Error creating continuous player: \(error)")
        }
    }
    
    func start() {
        NSLog("🔔 HapticManager: start() - Preparing haptics")
        guard isSupported else { return }

        do {
            try engine?.start()
            isEngineRunning = true
            NSLog("🔔 HapticManager: Engine prepared")
            
            // Give a small transient kick so the user feels it activating
            playTestHaptic()
            
            // Note: We don't start the continuous player here. 
            // updateIntensity() will create and start it when the first wave/level reaches it.
        } catch {
            NSLog("🔔 HapticManager: Failed to prepare haptic engine: \(error)")
        }
    }
    
    func stop() {
        NSLog("🔔 HapticManager: stop() - Deactivating vibration")
        guard isSupported else { return }
        try? continuousPlayer?.stop(atTime: 0)
        continuousPlayer = nil
    }
    
    func updateIntensity(_ intensity: Double) {
        // level 0-100 -> intensity 0.0-1.0
        // We use a floor of 0.05 to keep the motor "warm" and prevent restart gaps
        let value = Float(max(0.05, min(1.0, intensity / 100.0)))
        
        guard isSupported else { return }
        guard let engine = engine else { return }
        
        if !isEngineRunning {
            do {
                try engine.start()
                isEngineRunning = true
                NSLog("🔔 HapticManager: Engine restarted during updateIntensity")
            } catch {
                NSLog("🔔 HapticManager: Failed to restart engine for update: \(error)")
                return
            }
        }

        if continuousPlayer == nil {
            NSLog("🔔 HapticManager: continuousPlayer missing in updateIntensity, recreating...")
            createContinuousPlayer()
            do {
                try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
            } catch {
                NSLog("🔔 HapticManager: Failed to restart recreated player: \(error)")
                return
            }
        }

        guard let player = continuousPlayer else { return }

        // Dynamic parameters
        let sharpnessValue = Float(0.3 + (value * 0.4))
        let intensityParam = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: value, relativeTime: 0)
        let sharpnessParam = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpnessValue, relativeTime: 0)
        
        do {
            try player.sendParameters([intensityParam, sharpnessParam], atTime: CHHapticTimeImmediate)
        } catch {
            // Only invalidate on severe errors, and attempt to recreate next time
            NSLog("🔔 HapticManager: sendParameters failed: \(error). Resetting player.")
            continuousPlayer = nil
        }
    }
}
