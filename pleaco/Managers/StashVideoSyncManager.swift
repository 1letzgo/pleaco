//
//  StashVideoSyncManager.swift
//  pleaco
//

#if !os(tvOS)
import Foundation
import AVFoundation
import Vision
import Combine
import SwiftUI

class StashVideoSyncManager: ObservableObject {
    static let shared = StashVideoSyncManager()

    // MARK: - Published Channels (0.0 – 1.0)
    
    @Published var hipIntensity: Float = 0.0      // vertical rhythmic intensity
    @Published var headIntensity: Float = 0.0     // upper tracking movement
    @Published var pelvisIntensity: Float = 0.0   // lower core movement
    @Published var wristIntensity: Float = 0.0    // manual action speed
    @Published var horzIntensity: Float = 0.0     // lateral flow dominance

    /// Backwards-compat: toy managers subscribe to $currentIntensity
    @Published var currentIntensity: Float = 0.0

    @Published var isActive: Bool = false
    @Published var frameCounter: Int = 0
    @Published var lastError: String?

    // Vision sync is now always enabled when active
    var isVideoSyncEnabled: Bool = true
    @AppStorage("video_sync_sensitivity") var sensitivity: Double = 0.5
    @AppStorage("video_sync_smoothing") var smoothing: Double = 0.3

    @Published var isRecording: Bool = false

    // MARK: - Private Properties
    
    private var currentPlayerTime: Double = 0
    private var currentItem: AVPlayerItem?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private var previousPixelBuffer: CVPixelBuffer?

    // Head tracking
    private var previousHeadCentroid: CGPoint?

    // Hip/optical-flow rhythm tracking
    private var previousDominantVy: Float = 0
    private var previousDominantVx: Float = 0
    private var recentSpeedHistory: [Float] = []
    private let speedHistorySize = 8
    private var reversalTimestamps: [Int] = []
    private let reversalWindowFrames = 90       // ~3s at 30fps

    // Pelvis joint tracking (from body pose)
    private var previousPelvisCentroid: CGPoint?
    private var previousPelvisY: Float = 0.5
    private var pelvisReversalTimestamps: [Int] = []

    // Wrist tracking (from body pose)
    private var previousLeftWrist: CGPoint?
    private var previousRightWrist: CGPoint?
    private var wristSpeedHistory: [Float] = []
    private let wristHistorySize = 6
    
    // Wave modulation
    private var currentVerticalVelocity: Float = 0

    private var cancellables = Set<AnyCancellable>()
    private let analysisQueue = DispatchQueue(label: "com.pleaco.videoanalysis", qos: .userInteractive)
    private var isProcessing = false

    // Vision requests — reused across frames
    private let segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let r = VNGeneratePersonSegmentationRequest()
        if #available(iOS 15, macOS 12, *) { 
            r.qualityLevel = .accurate 
        }
        r.outputPixelFormat = kCVPixelFormatType_OneComponent32Float
        return r
    }()
    private let poseRequest = VNDetectHumanBodyPoseRequest()

    private init() {
        // Sync intensity to DeviceManager
        $currentIntensity
            .receive(on: RunLoop.main)
            .sink { [weak self] intensity in
                guard let self = self, self.isActive else { return }
                DeviceManager.shared.setLevel(Double(intensity) * 100.0)
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup & Control
    
    func setup(for playerItem: AVPlayerItem, player: AVPlayer, title: String? = nil) {
        cleanup()
        self.currentItem = playerItem

        // Register player with DeviceManager for unified control
        DeviceManager.shared.clearAllPrograms(except: .video)
        DeviceManager.shared.activeVideoPlayer = player
        DeviceManager.shared.activeVideoTitle = title

        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        if let output = videoOutput { playerItem.add(output) }

        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
        
        // Listen for video end
        NotificationCenter.default.addObserver(self, selector: #selector(videoDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        isActive = true
        NSLog("🔔 StashVideoSyncManager: Setup complete")
    }

    @objc private func updateDisplayLink(link: CADisplayLink) {
        guard isActive, let output = videoOutput else { return }
        
        // If player is paused, ensure intensity is 0
        if let player = DeviceManager.shared.activeVideoPlayer {
            if player.rate == 0 {
                if currentIntensity != 0 {
                    DispatchQueue.main.async {
                        self.currentIntensity = 0
                        DeviceManager.shared.setLevel(0)
                    }
                }
                return
            } else if !DeviceManager.shared.isPlaying {
                // Auto-start hardware if video is playing but DeviceManager is stopped
                DispatchQueue.main.async {
                    DeviceManager.shared.start()
                }
            }
        }

        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        self.currentPlayerTime = itemTime.seconds
        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                processFrame(pixelBuffer)
            }
        }
    }

    @objc private func videoDidEnd(notification: Notification) {
        NSLog("🔔 StashVideoSyncManager: Video ended - Looping")
        DispatchQueue.main.async {
            if let player = DeviceManager.shared.activeVideoPlayer {
                player.seek(to: .zero)
                player.play()
            }
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isProcessing else { return }
        isProcessing = true
        let localCounter = frameCounter

        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            // --- Stage A: Person Segmentation ---
            var personMask: CVPixelBuffer? = nil
            let segHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try segHandler.perform([self.segmentationRequest])
                personMask = self.segmentationRequest.results?.first?.pixelBuffer
            } catch {
                DispatchQueue.main.async { self.lastError = "Seg: \(error.localizedDescription)" }
            }

            // --- Stage B: Optical Flow → hip rhythm + horizontal motion ---
            if let previous = self.previousPixelBuffer {
                let flowRequest = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: previous, options: [:])
                flowRequest.computationAccuracy = .low
                let flowHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try flowHandler.perform([flowRequest])
                    if let result = flowRequest.results?.first as? VNPixelBufferObservation {
                        self.analyzeOpticalFlow(result.pixelBuffer, mask: personMask)
                    }
                } catch {
                    DispatchQueue.main.async { self.lastError = "Flow: \(error.localizedDescription)" }
                }
            }
            self.previousPixelBuffer = pixelBuffer

            // --- Stage C: Full Body Pose (every 6th frame) ---
            if localCounter % 6 == 0 {
                let poseHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try poseHandler.perform([self.poseRequest])
                    if let observation = self.poseRequest.results?.first {
                        self.analyzeHeadMovement(observation)
                        self.analyzePelvisMovement(observation)
                        self.analyzeWristMovement(observation)
                    } else {
                        DispatchQueue.main.async {
                            self.headIntensity *= 0.5
                            self.pelvisIntensity *= 0.7
                            self.wristIntensity *= 0.7
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.headIntensity *= 0.5
                        self.pelvisIntensity *= 0.7
                        self.wristIntensity *= 0.7
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.headIntensity *= 0.90
                    self.pelvisIntensity *= 0.95
                    self.wristIntensity *= 0.93
                }
            }

            DispatchQueue.main.async { self.frameCounter += 1 }
        }
    }

    // MARK: - Analysis Methods

    private func analyzeOpticalFlow(_ flowBuffer: CVPixelBuffer, mask: CVPixelBuffer?) {
        CVPixelBufferLockBaseAddress(flowBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(flowBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(flowBuffer) else { return }
        let width = CVPixelBufferGetWidth(flowBuffer)
        let height = CVPixelBufferGetHeight(flowBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(flowBuffer)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
        let floatsPerRow = bytesPerRow / 4
        let sampleStep = 6

        var maskBaseAddr: UnsafeMutableRawPointer? = nil
        var maskWidth = 0
        var maskHeight = 0
        var maskBytesPerRow = 0
        if let mask = mask {
            CVPixelBufferLockBaseAddress(mask, .readOnly)
            maskBaseAddr = CVPixelBufferGetBaseAddress(mask)
            maskWidth = CVPixelBufferGetWidth(mask)
            maskHeight = CVPixelBufferGetHeight(mask)
            maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        }
        defer { if let mask = mask { CVPixelBufferUnlockBaseAddress(mask, .readOnly) } }

        var vySum: Float = 0
        var vxSum: Float = 0
        var magSum: Float = 0
        var vxAbsSum: Float = 0   // for horizontal dominance ratio
        var vyAbsSum: Float = 0
        var sampleCount = 0
        // Optical flow values are in pixels. 0.35 pixels is a reasonable noise floor.
        let noiseFloor = Float(0.35 / (sensitivity + 0.1))

        for y in stride(from: 0, to: height, by: sampleStep) {
            let rowOffset = y * floatsPerRow
            for x in stride(from: 0, to: width, by: sampleStep) {
                if let maskAddr = maskBaseAddr {
                    let maskX = x * maskWidth / width
                    let maskY = y * maskHeight / height
                    let maskFloatsPerRow = maskBytesPerRow / 4
                    let maskVal = maskAddr.assumingMemoryBound(to: Float.self)[maskY * maskFloatsPerRow + maskX]
                    if maskVal < 0.5 { continue }
                }
                let offset = rowOffset + (x * 2)
                let vx = floatBuffer[offset]
                let vy = floatBuffer[offset + 1]
                let mag = sqrt(vx * vx + vy * vy)
                if mag > noiseFloor {
                    vySum += vy
                    vxSum += vx
                    magSum += mag
                    vxAbsSum += abs(vx)
                    vyAbsSum += abs(vy)
                    sampleCount += 1
                }
            }
        }

        let currentFrame = frameCounter
        reversalTimestamps = reversalTimestamps.filter { currentFrame - $0 <= reversalWindowFrames }

        guard sampleCount > 4 else {
            DispatchQueue.main.async {
                self.currentVerticalVelocity *= 0.7  // Rapid decay of wave pulse
                self.hipIntensity = self.hipIntensity * Float(self.smoothing)
                self.horzIntensity *= 0.85
                self.currentIntensity = self.computeCurrentIntensity()
            }
            return
        }

        let dominantVy = vySum / Float(sampleCount)
        let dominantVx = vxSum / Float(sampleCount)
        let avgMag = magSum / Float(sampleCount)

        let rawRatio = vxAbsSum / max(0.001, vxAbsSum + vyAbsSum)
        let horzRatio = max(0.0, (rawRatio - 0.55) / 0.45)

        recentSpeedHistory.append(avgMag)
        if recentSpeedHistory.count > speedHistorySize { recentSpeedHistory.removeFirst() }
        let recentAvgSpeed = recentSpeedHistory.reduce(0, +) / Float(recentSpeedHistory.count)

        let s = Float(sensitivity)

        let prevVy = previousDominantVy
        // Optical flow units are pixels. 0.08 pixels average is a better threshold for noise.
        let vertReversed = (prevVy > 0.08 && dominantVy < -0.08) || (prevVy < -0.08 && dominantVy > 0.08)
        previousDominantVy = dominantVy
        previousDominantVx = dominantVx

        if vertReversed { reversalTimestamps.append(currentFrame) }
        
        // Recalculate frequency after potential new reversal
        let updatedReversals = Float(reversalTimestamps.count)
        let updatedFreq = updatedReversals / (Float(reversalWindowFrames) / 30.0)
        
        let speedActive = recentAvgSpeed > (0.04 / max(0.1, s))
        let freqRaw: Float = !speedActive || updatedReversals < 1 ? 0.0 : min(1.0, updatedFreq / 3.0)
        
        // Weight hip level by speed to ensure it decays naturally when motion stops
        let hipLevel = freqRaw * min(1.0, recentAvgSpeed * 12.0)
        self.currentVerticalVelocity = abs(dominantVy)
        
        let horzLevel = min(1.0, recentAvgSpeed * horzRatio * s * 4.0)

        let sm = Float(smoothing)
        DispatchQueue.main.async {
            self.hipIntensity = min(1.0, self.hipIntensity * sm + hipLevel * (1.0 - sm))
            self.horzIntensity = self.horzIntensity * 0.6 + horzLevel * 0.4
            self.currentIntensity = self.computeCurrentIntensity()
            
            // Log every 15 frames (~0.5s) for analysis
            if currentFrame % 15 == 0 {
                NSLog("📊 VR: %d revs | Freq: %.2f | SpeedWeight: %.2f | RawInt: %.2f | SmoothInt: %.2f", 
                      Int(updatedReversals), updatedFreq, min(1.0, recentAvgSpeed * 12.0), hipLevel, self.hipIntensity)
            }
        }
    }

    private func analyzeHeadMovement(_ observation: VNHumanBodyPoseObservation) {
        let headJoints: [VNHumanBodyPoseObservation.JointName] = [.neck, .leftEar, .rightEar, .nose]
        var points: [CGPoint] = []
        for joint in headJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                points.append(point.location)
            }
        }
        guard !points.isEmpty else {
            DispatchQueue.main.async { self.headIntensity *= 0.5 }
            return
        }
        let centroid = CGPoint(
            x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
            y: points.map(\.y).reduce(0, +) / CGFloat(points.count)
        )
        let sm = Float(smoothing)
        if let prev = previousHeadCentroid {
            let dx = Float(centroid.x - prev.x)
            let dy = Float(centroid.y - prev.y)
            let delta = sqrt(dx * dx + dy * dy)
            let normalized = min(1.0, (delta / 0.10) * Float(sensitivity))
            if normalized < 0.02 {
                DispatchQueue.main.async { self.headIntensity *= 0.5 }
            } else {
                DispatchQueue.main.async {
                    self.headIntensity = min(1.0, self.headIntensity * sm + normalized * (1.0 - sm))
                }
            }
        }
        previousHeadCentroid = centroid
    }

    private func analyzePelvisMovement(_ observation: VNHumanBodyPoseObservation) {
        let currentFrame = frameCounter
        pelvisReversalTimestamps = pelvisReversalTimestamps.filter { currentFrame - $0 <= reversalWindowFrames }

        let pelvisJoints: [VNHumanBodyPoseObservation.JointName] = [.leftHip, .rightHip, .root]
        var points: [CGPoint] = []
        for joint in pelvisJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                points.append(point.location)
            }
        }
        guard !points.isEmpty else {
            DispatchQueue.main.async { self.pelvisIntensity *= 0.6 }
            return
        }
        let centroid = CGPoint(
            x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
            y: points.map(\.y).reduce(0, +) / CGFloat(points.count)
        )

        if let prev = previousPelvisCentroid {
            let dx = Float(centroid.x - prev.x)
            let dy = Float(centroid.y - prev.y)
            let delta = sqrt(dx * dx + dy * dy)
            let s = Float(sensitivity)

            let normalized = min(1.0, (delta / 0.05) * s)

            guard normalized > 0.01 else {
                DispatchQueue.main.async { self.pelvisIntensity *= Float(self.smoothing) }
                return
            }
            
            let prevY = previousPelvisY
            if (prevY > 0.52 && normalized < 0.48) || (prevY < 0.48 && normalized > 0.52) {
                pelvisReversalTimestamps.append(currentFrame)
            }
            previousPelvisY = normalized
            
            let pelvisReversals = Float(pelvisReversalTimestamps.count)
            let pelvisFreq = pelvisReversals / (Float(reversalWindowFrames) / 30.0)
            let pelvisLevel = normalized > 0.05 ? min(1.0, pelvisFreq / 3.0) : normalized * 0.5

            let sm = Float(smoothing)
            DispatchQueue.main.async {
                self.pelvisIntensity = min(1.0, self.pelvisIntensity * sm + pelvisLevel * (1.0 - sm))
                self.currentIntensity = self.computeCurrentIntensity()
            }
        }
        previousPelvisCentroid = centroid
    }

    private func analyzeWristMovement(_ observation: VNHumanBodyPoseObservation) {
        let joints: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.leftWrist, .leftElbow),
            (.rightWrist, .rightElbow)
        ]

        var totalDelta: Float = 0
        var count = 0

        for arm in joints {
            var armPoints: [CGPoint] = []
            if let w = try? observation.recognizedPoint(arm.0), w.confidence > 0.3 { armPoints.append(w.location) }
            if let e = try? observation.recognizedPoint(arm.1), e.confidence > 0.3 { armPoints.append(e.location) }
            
            if !armPoints.isEmpty {
                let centroid = CGPoint(x: armPoints.map(\.x).reduce(0,+)/CGFloat(armPoints.count),
                                     y: armPoints.map(\.y).reduce(0,+)/CGFloat(armPoints.count))
                
                let prev = arm.0 == .leftWrist ? previousLeftWrist : previousRightWrist
                if let prev = prev {
                    let dx = Float(centroid.x - prev.x)
                    let dy = Float(centroid.y - prev.y)
                    totalDelta += sqrt(dx*dx + dy*dy)
                    count += 1
                }
                
                if arm.0 == .leftWrist { previousLeftWrist = centroid } 
                else { previousRightWrist = centroid }
            }
        }

        guard count > 0 else {
            DispatchQueue.main.async { self.wristIntensity *= 0.7 }
            return
        }

        let avgDelta = totalDelta / Float(count)
        let s = Float(sensitivity)
        let normalized = min(1.0, (avgDelta / 0.08) * s)

        wristSpeedHistory.append(normalized)
        if wristSpeedHistory.count > wristHistorySize { wristSpeedHistory.removeFirst() }
        let smoothedWrist = min(1.0, wristSpeedHistory.reduce(0,+) / Float(wristSpeedHistory.count))

        let sm = Float(smoothing)
        DispatchQueue.main.async {
            if normalized < 0.03 {
                self.wristIntensity *= 0.6
            } else {
                self.wristIntensity = min(1.0, self.wristIntensity * sm + smoothedWrist * (1.0 - sm))
            }
            self.currentIntensity = self.computeCurrentIntensity()
        }
    }

    private func computeCurrentIntensity() -> Float {
        let s = Float(sensitivity)
        let thrustSignal  = (hipIntensity + pelvisIntensity) * 0.5
        let manualSignal  = (headIntensity + wristIntensity) * 0.5
        let baseSignal = max(thrustSignal, manualSignal)

        // Wave logic:
        // currentVerticalVelocity (abs(dominantVy)) is in pixels/frame.
        // In action scenes, typical values are 1.0 – 8.0.
        // We scale it so ~3.0 pixels/frame starts to reach 1.0 saturation at mid-sensitivity (0.5).
        let normalizedVelocity = min(1.0, currentVerticalVelocity * (0.3 + s * 0.6))
        
        // Final intensity = baseSignal (overall energy) * modulator (instantaneous movement)
        // We keep the floor at 20% to ensure a clear "dip" at reversals
        let finalValue = baseSignal * (0.2 + 0.8 * normalizedVelocity)
        
        if frameCounter % 15 == 0 {
            NSLog("🌊 Wave: Vel: %.3f | NormVel: %.2f | Base: %.2f | Final: %.2f", 
                  currentVerticalVelocity, normalizedVelocity, baseSignal, finalValue)
        }

        // Continuous ceiling based on sensitivity
        let ceiling: Float = s < 0.3 ? 0.4 : (s < 0.7 ? 0.8 : 1.0)
        return min(ceiling, finalValue)
    }

    // MARK: - Lifecycle

    func stop() {
        isActive = false
        cleanup()
        NSLog("🛑 StashVideoSyncManager: Stopped")
    }

    private func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        
        if let output = videoOutput, let item = currentItem { item.remove(output) }
        
        // Remove player from DeviceManager
        if let currentItem = self.currentItem,
           DeviceManager.shared.activeVideoPlayer?.currentItem == currentItem {
             DeviceManager.shared.activeVideoPlayer = nil
             DeviceManager.shared.activeVideoTitle = nil
        }
        
        videoOutput = nil
        currentItem = nil
        previousPixelBuffer = nil
        previousHeadCentroid = nil
        previousPelvisCentroid = nil
        previousLeftWrist = nil
        previousRightWrist = nil
        previousDominantVy = 0
        previousDominantVx = 0
        recentSpeedHistory = []
        wristSpeedHistory = []
        reversalTimestamps = []
        pelvisReversalTimestamps = []
        hipIntensity = 0
        headIntensity = 0
        pelvisIntensity = 0
        wristIntensity = 0
        horzIntensity = 0
        currentIntensity = 0
        currentVerticalVelocity = 0
        lastError = nil
    }
}
#endif
