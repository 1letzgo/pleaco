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

    private let analysisQueue = DispatchQueue(label: "com.pleaco.audioAnalysis")
    private var theRms: Float = 0.0
    private var timeObserverTimer: Timer?

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
            // Stop the node first to clear any previously scheduled buffers
            playerNode.stop()
            
            // Re-schedule the file from the beginning
            playerNode.scheduleFile(file, at: nil) {
                DispatchQueue.main.async {
                    self.stop()
                }
            }
            
            try engine.start()
            playerNode.play()
            
            isPlaying = true
            DeviceManager.shared.start() // Ensure haptics/toys are ready to receive commands
            
            startTimeObserver()
            print("Audio Mixer Tap started...")
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }

    func pause() {
        playerNode.pause()
        engine.pause()
        isPlaying = false
        DeviceManager.shared.setLevel(0.0) // Stop vibrations
        stopTimeObserver()
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
        currentAmplitude = 0.0
        currentTime = 0
        DeviceManager.shared.setLevel(0.0)
        stopTimeObserver()
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
        
        // Calculate Root Mean Square (RMS) for amplitude
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        var sumSquares: Float = 0.0

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                let sample = data[frame]
                sumSquares += sample * sample
            }
        }

        let totalSamples = Float(channelCount * frameLength)
        let rms = sqrt(sumSquares / totalSamples)
        
        self.theRms = rms

        // Map RMS (usually 0.0 to ~0.3 in typical music) to 0.0-100.0 intensity
        // We use the 'sensitivity' modifier to allow user tuning
        
        let sensitivityMultiplier = Float(self.sensitivity) / 50.0 // 1.0 at 50% slider
        
        // Boost factor: Multiply the Raw RMS to get to a 0-100 scale.
        // E.g. raw RMS of 0.2 * 300 = 60
        let boostFactor: Float = 400.0
        var intensity = Double(rms * boostFactor * sensitivityMultiplier)
        
        // Cap it
        intensity = min(100.0, max(0.0, intensity))
        
        // A little threshold smoothing - don't vibrate for tiny background hiss
        if intensity < 5.0 {
            intensity = 0.0
        }

        DispatchQueue.main.async {
            self.currentAmplitude = intensity
            
            // Send to the devices immediately!
            // Note: Since this block triggers very frequently (e.g., ~40 times a second),
            // The DeviceManager's internal throttling (e.g. HandyManager/OSSMManager deduplication)
            // handles filtering out spam to BLE hardware.
            DeviceManager.shared.setLevel(intensity)
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

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        
        let sampleRate = file.fileFormat.sampleRate
        let targetFrame = AVAudioFramePosition(time * sampleRate)
        let totalFrames = file.length
        
        // Ensure we seek within bounds
        let validFrame = max(0, min(targetFrame, totalFrames))
        let remainingFrames = AVAudioFrameCount(totalFrames - validFrame)
        
        playerNode.stop()
        
        if remainingFrames > 0 {
            playerNode.scheduleSegment(file, startingFrame: validFrame, frameCount: remainingFrames, at: nil) {
                DispatchQueue.main.async {
                    self.stop()
                }
            }
        }
        
        seekOffset = Double(validFrame) / sampleRate
        currentTime = seekOffset
        
        if isPlaying {
            playerNode.play()
        }
    }
}
