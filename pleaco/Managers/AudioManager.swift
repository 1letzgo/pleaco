//
//  AudioManager.swift
//  pleaco
//

import Foundation
import AVFoundation
import Combine

class AudioManager: ObservableObject {
    static let shared = AudioManager()

    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentAmplitude: Double = 0.0
    @Published var sensitivity: Double = 50.0 // 1-100 scale for user to adjust vibration strength
    @Published var trackName: String = "No Track Loaded"
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    @Published var savedTracks: [SavedAudioTrack] = []

    // MARK: - Private Properties
    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var delayNode: AVAudioUnitDelay
    private var audioFile: AVAudioFile?
    
    private var seekOffset: TimeInterval = 0
    private var scheduleToken: Int = 0
    private var isSeeking = false
    private var isPaused = false

    private let analysisQueue = DispatchQueue(label: "com.pleaco.audioAnalysis")
    private var theRms: Float = 0.0
    private var timeObserverTimer: Timer?
    
    // Per-channel LPF state
    private var filterState: [Float] = [0, 0] // Supports stereo
    private var smoothedIntensity: Double = 0
    private var peakRms: Float = 0.05 // Baseline peak for AGC

    private let fileManager = FileManager.default
    private var audioDirectoryURL: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("AudioTracks")
    }

    private init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        delayNode = AVAudioUnitDelay()

        // 230ms delay to offset Bluetooth latency for Toys
        delayNode.delayTime = 0.23
        delayNode.wetDryMix = 100 // 100% wet, so audio is fully delayed
        delayNode.feedback = 0    // CRITICAL: No echo/reverb
        delayNode.lowPassCutoff = 22000 // Ensure full transparency

        engine.attach(playerNode)
        engine.attach(delayNode)
        
        engine.connect(playerNode, to: delayNode, format: nil)
        engine.connect(delayNode, to: engine.mainMixerNode, format: nil)

        // Ensure we can mix audio with other apps or our own internal haptics
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category. Error: \(error)")
        }

        createAudioDirectoryIfNeeded()
        loadSavedTracks()
    }

    // MARK: - Public Methods

    private func createAudioDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try? fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }
    }

    func loadSavedTracks() {
        do {
            let files = try fileManager.contentsOfDirectory(at: audioDirectoryURL, includingPropertiesForKeys: nil)
            let supportedExtensions = ["mp3", "wav", "m4a"]
            
            let tracks = files.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
                .map { url in
                    SavedAudioTrack(id: UUID(), name: url.deletingPathExtension().lastPathComponent, fileName: url.lastPathComponent)
                }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            DispatchQueue.main.async {
                self.savedTracks = tracks
            }
        } catch {
            print("Error loading tracks from directory: \(error)")
        }
    }

    func importTrack(from tempURL: URL) {
        let fileName = tempURL.lastPathComponent
        let destinationURL = audioDirectoryURL.appendingPathComponent(fileName)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            loadSavedTracks()
            
            // Automatically select and load it
            if let newTrack = savedTracks.first(where: { $0.fileName == fileName }) {
                loadTrack(newTrack)
            }
        } catch {
            print("Error importing track: \(error)")
        }
    }

    func deleteTrack(_ track: SavedAudioTrack) {
        let fileURL = audioDirectoryURL.appendingPathComponent(track.fileName)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                loadSavedTracks()
            }
        } catch {
            print("Error deleting track: \(error)")
        }
    }

    func loadTrack(_ track: SavedAudioTrack) {
        let url = audioDirectoryURL.appendingPathComponent(track.fileName)
        loadAudioFile(url: url)
    }

    private func loadAudioFile(url: URL) {
        stop()
        seekOffset = 0
        currentTime = 0
        isPaused = false

        do {
            audioFile = try AVAudioFile(forReading: url)
            trackName = url.deletingPathExtension().lastPathComponent
            
            if let file = audioFile {
                let sampleRate = file.fileFormat.sampleRate
                let frameCount = Double(file.length)
                DispatchQueue.main.async {
                    self.duration = frameCount / sampleRate
                }
            }
            
            setupAudioEngine()
        } catch {
            print("Error loading audio file: \(error.localizedDescription)")
            trackName = "Error Loading Track"
        }
    }

    func play() {
        guard let file = audioFile else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if isPaused {
                // Engine was paused — just restart it and resume the player node
                try engine.start()
                playerNode.play()
                isPlaying = true
                isPaused = false
                startTimeObserver()
                return
            }

            if !engine.isRunning {
                try engine.start()
            }

            // Schedule from currentTime (set to 0 by stop(), or preserved by pause/seek)
            if !isPlaying {
                playerNode.stop() // Clear internal state

                let sampleRate = file.fileFormat.sampleRate
                let targetFrame = AVAudioFramePosition(currentTime * sampleRate)
                let totalFrames = file.length

                let startFrame = max(0, min(targetFrame, totalFrames))
                let remainingFrames = AVAudioFrameCount(totalFrames - startFrame)

                if remainingFrames > 0 {
                    let token = scheduleToken
                    playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: remainingFrames, at: nil) { [weak self] in
                        guard let self = self, self.scheduleToken == token else { return }
                        DispatchQueue.main.async {
                            if self.currentTime >= self.duration - 0.2 {
                                self.playNext()
                            } else {
                                self.stop()
                            }
                        }
                    }
                }
            }

            playerNode.play()
            isPlaying = true
            DeviceManager.shared.start()
            startTimeObserver()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }
    
    // MARK: - Track Skipping Navigation
    
    func playNext() {
        guard !savedTracks.isEmpty else { return }
        let currentFileName = audioFile?.url.lastPathComponent
        guard let currentIndex = savedTracks.firstIndex(where: { $0.fileName == currentFileName }) else { return }
        
        let nextIndex = (currentIndex + 1) % savedTracks.count
        let nextTrack = savedTracks[nextIndex]
        
        DeviceManager.shared.applyAudioTrack(nextTrack)
    }

    func playPrevious() {
        guard !savedTracks.isEmpty else { return }
        let currentFileName = audioFile?.url.lastPathComponent
        guard let currentIndex = savedTracks.firstIndex(where: { $0.fileName == currentFileName }) else { return }
        
        let prevIndex = (currentIndex - 1 >= 0) ? (currentIndex - 1) : (savedTracks.count - 1)
        let prevTrack = savedTracks[prevIndex]
        
        DeviceManager.shared.applyAudioTrack(prevTrack)
    }

    func setMuted(_ muted: Bool) {
        engine.mainMixerNode.outputVolume = muted ? 0.0 : 1.0
    }

    func pause() {
        playerNode.pause()
        engine.pause()
        isPlaying = false
        isPaused = true
        DeviceManager.shared.setLevel(0.0) // Stop vibrations
        stopTimeObserver()
        
        // Restore background audio mixing
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AudioSession error") }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
        isPaused = false
        currentAmplitude = 0.0
        currentTime = 0
        seekOffset = 0
        DeviceManager.shared.setLevel(0.0)
        stopTimeObserver()
        
        // Restore background audio mixing
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AudioSession error") }
    }

    // MARK: - Private Audio Analysis

    private func setupAudioEngine() {
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)

        mixer.removeTap(onBus: 0) // Remove any existing tap

        // Install a tap to read the audio levels in real-time
        mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, time) in
            guard let self = self, self.isPlaying else { return }

            self.analysisQueue.async {
                self.processBuffer(buffer)
            }
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // Low Pass Filter Calculation (Target: ~100Hz for cleaner kick drums)
        let cutoff: Float = 100.0
        let dt = 1.0 / sampleRate
        let rc = 1.0 / (2.0 * .pi * cutoff)
        let alpha = dt / (rc + dt)
        let oneMinusAlpha = 1.0 - alpha

        var sumSquares: Float = 0.0

        for channel in 0..<min(channelCount, 2) {
            let data = channelData[channel]
            var lastY = filterState[channel]
            
            for frame in 0..<frameLength {
                let x = data[frame]
                let y = alpha * x + oneMinusAlpha * lastY
                sumSquares += y * y
                lastY = y
            }
            filterState[channel] = lastY
        }

        let totalSamples = Float(min(channelCount, 2) * frameLength)
        let rms = sqrt(sumSquares / totalSamples)
        self.theRms = rms

        // Peak Tracking (Auto-Gain Control)
        // Fast attack, slow decay (approx 5-10 seconds to decay fully)
        if rms > peakRms {
            peakRms = rms // Instant attack
        } else {
            peakRms = (peakRms * 0.9995) + (rms * 0.0005) // Slow decay
        }
        
        // Ensure peakRms doesn't get too small (silence floor)
        peakRms = max(peakRms, 0.01)

        // Map RMS to intensity relative to peak
        let sensitivityMultiplier = Float(self.sensitivity) / 50.0
        
        // Dynamic Scaling: current RMS / current Peak * 100
        var targetIntensity = Double((rms / peakRms) * 100.0 * sensitivityMultiplier)
        
        // Noise Gate
        if targetIntensity < 15.0 {
            targetIntensity = 0.0
        }
        
        // Smoothing (Attack/Release)
        // Rock music needs faster response to be rhythmic
        let smoothAlpha = targetIntensity > smoothedIntensity ? 0.4 : 0.15
        smoothedIntensity = (targetIntensity * smoothAlpha) + (smoothedIntensity * (1.0 - smoothAlpha))
        
        // Cap it at user's master audio intensity
        let finalIntensity = min(DeviceManager.shared.audioIntensity, max(0.0, smoothedIntensity))

        DispatchQueue.main.async {
            guard self.isPlaying else { return }
            self.currentAmplitude = finalIntensity
            DeviceManager.shared.setLevel(finalIntensity)
        }
    }

    private func startTimeObserver() {
        timeObserverTimer?.invalidate()
        timeObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let nodeTime = self.playerNode.lastRenderTime, let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) {
                // Incorporate the seek offset and 230ms BT delay node time
                let calculatedTime = (Double(playerTime.sampleTime) / playerTime.sampleRate) + self.seekOffset
                self.currentTime = min(max(calculatedTime, 0), self.duration)
            }
        }
    }

    private func stopTimeObserver() {
        timeObserverTimer?.invalidate()
        timeObserverTimer = nil
    }
    
    func pauseTimeObserver() {
        timeObserverTimer?.invalidate()
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        
        isSeeking = true
        scheduleToken += 1
        let token = scheduleToken
        isPaused = false
        playerNode.stop()

        let sampleRate = file.fileFormat.sampleRate
        let targetFrame = AVAudioFramePosition(time * sampleRate)
        let totalFrames = file.length

        // Ensure we seek within bounds
        let validFrame = max(0, min(targetFrame, totalFrames))
        let remainingFrames = AVAudioFrameCount(totalFrames - validFrame)

        seekOffset = Double(validFrame) / sampleRate
        currentTime = seekOffset

        if remainingFrames > 0 {
            playerNode.scheduleSegment(file, startingFrame: validFrame, frameCount: remainingFrames, at: nil) { [weak self] in
                guard let self = self, self.scheduleToken == token else { return }
                DispatchQueue.main.async {
                    self.stop()
                }
            }
        }
        
        if isPlaying {
            playerNode.play()
            startTimeObserver()
        }
        
        isSeeking = false
    }
}
