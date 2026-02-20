//
//  AudioReactiveManager.swift
//  pleaco
//
//  Captures audio from the device microphone via AVAudioEngine and computes
//  a normalised RMS level (0–1) that drives device intensity.
//  Uses .playAndRecord + .mixWithOthers so music keeps playing.
//

import Foundation
import Combine
import AVFoundation

class AudioReactiveManager: ObservableObject {
    static let shared = AudioReactiveManager()

    @Published var normalizedLevel: Double = 0
    @Published var isCapturing: Bool = false
    @Published var captureError: String?

    private var audioEngine: AVAudioEngine?
    private var peakLevel: Double = 0

    private init() {}

    // MARK: - Microphone Capture

    func startCapture() {
        guard !isCapturing else { return }
        peakLevel = 0

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            let msg = "Audio session failed: \(error.localizedDescription)"
            print("AudioReactive: \(msg)")
            DispatchQueue.main.async { self.captureError = msg }
            return
        }
        #endif

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.sampleRate > 0, format.channelCount > 0 else {
            DispatchQueue.main.async { self.captureError = "No audio input available" }
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
            audioEngine = engine
            DispatchQueue.main.async {
                self.isCapturing = true
                self.captureError = nil
            }
            print("AudioReactive: Mic capture started (sampleRate: \(format.sampleRate))")
        } catch {
            let msg = "Engine start failed: \(error.localizedDescription)"
            print("AudioReactive: \(msg)")
            DispatchQueue.main.async { self.captureError = msg }
        }
    }

    func stopCapture() {
        guard isCapturing else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioReactive: Deactivate failed: \(error.localizedDescription)")
        }
        #endif

        DispatchQueue.main.async {
            self.isCapturing = false
            self.normalizedLevel = 0
        }
        print("AudioReactive: Capture stopped")
    }

    // MARK: - Processing

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        // Full-band RMS
        var sumOfSquares: Float = 0
        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                sumOfSquares += data[frame] * data[frame]
            }
        }

        let rms = sqrt(sumOfSquares / Float(frameLength * channelCount))

        // Balanced gain (10×)
        let current = min(1.0, Double(rms) * 10.0)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Fast attack, slow decay — punchy response to beats
            if current > self.peakLevel {
                // Instant jump on transients (attack)
                self.peakLevel = current
            } else {
                // Slow decay (release)
                self.peakLevel *= 0.85
            }

            self.normalizedLevel = self.peakLevel
        }
    }
}
