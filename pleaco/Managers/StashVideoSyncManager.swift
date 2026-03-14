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
    
    @Published var hipIntensity: Float = 0.0      // vertical optical flow rhythm (thrust freq)
    @Published var headIntensity: Float = 0.0     // head/neck centroid movement
    @Published var pelvisIntensity: Float = 0.0   // hip joint (leftHip/rightHip/root) movement
    @Published var wristIntensity: Float = 0.0    // wrist/arm speed (handjob, fingering)
    @Published var horzIntensity: Float = 0.0     // horizontal flow dominance (sideways motion)

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
    private var pelvisReversalTimestamps: [Int] = []

    // Wrist tracking (from body pose)
    private var previousLeftWrist: CGPoint?
    private var previousRightWrist: CGPoint?
    private var wristSpeedHistory: [Float] = []
    private let wristHistorySize = 6

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
    
    func setup(for playerItem: AVPlayerItem, player: AVPlayer) {
        cleanup()
        self.currentItem = playerItem

        // Register player with DeviceManager for unified control
        DeviceManager.shared.activeVideoPlayer = player

        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        if let output = videoOutput { playerItem.add(output) }

        displayLink = CADisplayLink(target: self, selector: #selector(updateDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
        
        isActive = true
        NSLog("🔔 StashVideoSyncManager: Setup complete")
    }

    @objc private func updateDisplayLink(link: CADisplayLink) {
        guard isActive, let output = videoOutput else { return }
        let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
        self.currentPlayerTime = itemTime.seconds
        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                processFrame(pixelBuffer)
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
        let noiseFloor = Float(0.15 / (sensitivity + 0.1))

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

        guard sampleCount > 4 else {
            DispatchQueue.main.async {
                self.hipIntensity *= Float(self.smoothing)
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
        let levelCeiling: Float = s < 0.35 ? 0.33 : (s < 0.70 ? 0.66 : 1.0)

        let prevVy = previousDominantVy
        let vertReversed = (prevVy > 0.008 && dominantVy < -0.008) || (prevVy < -0.008 && dominantVy > 0.008)
        previousDominantVy = dominantVy
        previousDominantVx = dominantVx

        let currentFrame = frameCounter
        if vertReversed { reversalTimestamps.append(currentFrame) }
        reversalTimestamps = reversalTimestamps.filter { currentFrame - $0 <= reversalWindowFrames }

        let reversalsInWindow = Float(reversalTimestamps.count)
        let thrustFrequency = reversalsInWindow / (Float(reversalWindowFrames) / 30.0)
        let speedActive = recentAvgSpeed > (0.04 / max(0.1, s))

        let freqRaw: Float
        if !speedActive || reversalsInWindow < 1 {
            freqRaw = 0.0
        } else if thrustFrequency < 0.5 {
            freqRaw = 0.33
        } else if thrustFrequency < 1.5 {
            freqRaw = 0.66
        } else {
            freqRaw = 1.0
        }
        let hipLevel = min(levelCeiling, freqRaw)

        let horzLevel = min(1.0, recentAvgSpeed * horzRatio * s * 4.0)

        DispatchQueue.main.async {
            self.hipIntensity = hipLevel
            self.horzIntensity = self.horzIntensity * 0.6 + horzLevel * 0.4
            self.currentIntensity = self.computeCurrentIntensity()
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

            let currentFrame = frameCounter
            if let prevPrev = previousPelvisCentroid {
                let prevDyVal = Float(prevPrev.y - prev.y)
                let curDyVal = Float(prev.y - centroid.y)
                let pelvisReversed = (prevDyVal > 0.005 && curDyVal < -0.005) || (prevDyVal < -0.005 && curDyVal > 0.005)
                if pelvisReversed { pelvisReversalTimestamps.append(currentFrame) }
            }
            pelvisReversalTimestamps = pelvisReversalTimestamps.filter { currentFrame - $0 <= reversalWindowFrames }

            let pelvisReversals = Float(pelvisReversalTimestamps.count)
            let pelvisFreq = pelvisReversals / (Float(reversalWindowFrames) / 30.0)
            let freqLevel: Float = pelvisFreq < 0.5 ? 0.33 : (pelvisFreq < 1.5 ? 0.66 : 1.0)
            let levelCeiling: Float = s < 0.35 ? 0.33 : (s < 0.70 ? 0.66 : 1.0)
            let pelvisLevel = normalized > 0.05 ? min(levelCeiling, freqLevel) : normalized * 0.5

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
        let thrustSignal  = (hipIntensity + pelvisIntensity) * 0.5
        let manualSignal  = (headIntensity + wristIntensity) * 0.5
        let baseSignal = max(thrustSignal, manualSignal)

        let thresholdShift = horzIntensity * 0.28

        let t1 = max(0.10, 0.18 - thresholdShift)
        let t2 = max(0.25, 0.45 - thresholdShift)
        let t3 = max(0.45, 0.78 - thresholdShift)

        if baseSignal < t1 { return 0.0 }
        if baseSignal < t2 { return 0.33 }
        if baseSignal < t3 { return 0.66 }
        return 1.0
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
        if let output = videoOutput, let item = currentItem { item.remove(output) }
        
        // Remove player from DeviceManager
        if let currentItem = self.currentItem,
           DeviceManager.shared.activeVideoPlayer?.currentItem == currentItem {
             DeviceManager.shared.activeVideoPlayer = nil
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
        lastError = nil
    }
}
#endif
