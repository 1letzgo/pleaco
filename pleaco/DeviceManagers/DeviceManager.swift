//
//  DeviceManager.swift
//  pleaco
//

import Foundation
import SwiftUI
import Combine

extension UUID {
    static let internalDeviceID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

enum DeviceType: String, CaseIterable, Identifiable, Codable {
    case handy = "The Handy"
    case oh = "Oh."
    case intiface = "Intiface"
    case lovespouse = "LoveSpouse"
    case `internal` = "Phone Vibration"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .handy: return "hand.tap"
        case .oh: return "waveform"
        case .intiface: return "cable.connector"
        case .lovespouse: return "antenna.radiowaves.left.and.right"
        case .internal: return "iphone.gen3"
        }
    }
}

enum DeviceWavePreset: String, CaseIterable, Identifiable, Codable {
    case sine75 = "Steady"          // was "Sine 75Hz" — constant intensity baseline
    case foreplay = "Foreplay"
    case texture = "Texture"
    case build1 = "Throb"           // was "Build 1 (Slow Pulse)" — fixed waveform
    case build2 = "Flutter"         // was "Build 2 (Flutter)"
    case build3 = "Warming"         // was "Build 3 (Warming)"
    case climax1 = "Peak"           // was "Climax 1"
    case climax2 = "Edge"           // was "Climax 2"
    case aftercare = "Aftercare"
    case pulse = "Pulse"
    case fastPulse = "Rapid"        // was "Fast Pulse"
    case wave = "Wave"              // fixed: now 2Hz, distinct from Foreplay
    case slowWave = "Slow Wave"
    case ramp = "Ramp"              // fixed: triangle, no hard reset
    case heartbeat = "Heartbeat"
    case chaos = "Chaos"
    case tease = "Tease"
    case surge = "Surge"
    case bounce = "Bounce"
    case breathe = "Breathe"
    case staccato = "Staccato"
    case thunder = "Thunder"
    case climb = "Climb"
    case ocean = "Ocean"
    case earthquake = "Earthquake"

    var id: String { rawValue }

    var displayName: String { rawValue }
    
    var shortName: String { rawValue }
}

class SavedDevice: ObservableObject, Identifiable, Codable, Hashable {
    let id: UUID
    @Published var name: String
    @Published var type: DeviceType
    @Published var connectionKey: String
    @Published var serverAddress: String

    @Published var isConnected: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, type, connectionKey, serverAddress
    }
    
    static func == (lhs: SavedDevice, rhs: SavedDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    init(id: UUID = UUID(), name: String, type: DeviceType, connectionKey: String = "", serverAddress: String = "ws://127.0.0.1:12345") {
        self.id = id
        self.name = name
        self.type = type
        self.connectionKey = connectionKey
        self.serverAddress = serverAddress
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(DeviceType.self, forKey: .type)
        connectionKey = try container.decode(String.self, forKey: .connectionKey)
        serverAddress = try container.decode(String.self, forKey: .serverAddress)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(connectionKey, forKey: .connectionKey)
        try container.encode(serverAddress, forKey: .serverAddress)
    }
}

class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    @Published var devices: [SavedDevice] = []
    @Published var activeDeviceId: UUID?
    @Published var selectedPreset: DeviceWavePreset = .sine75
    @Published var isPlaying: Bool = false
    @Published var currentLevel: Double = 0
    @Published var strokeMin: Double = 0 {
        didSet { UserDefaults.standard.set(strokeMin, forKey: "strokeMin") }
    }
    @Published var strokeMax: Double = 100 {
        didSet { UserDefaults.standard.set(strokeMax, forKey: "strokeMax") }
    }

    
    @Published var defaultIntensity: Double = 50 {
        didSet {
            UserDefaults.standard.set(defaultIntensity, forKey: "defaultIntensity")
            if !isPlaying {
                currentLevel = defaultIntensity
            }
        }
    }
    

    private var handyManager = HandyManager.shared
    private var buttplugManager = ButtplugManager.shared
    private var loveSpouseManager = LoveSpouseManager.shared
    private var hapticManager = HapticManager.shared

    @Published var waveTime: Double = 0
    @Published var activeFunScript: FunScriptData? = nil
    @Published var activeFunScriptId: UUID? = nil
    @Published var funScriptPositionMs: Double = 0
    @Published var customScripts: [NamedFunScript] = []
    
    /// Persistent selection for LoveSpouse (1-9), independent of isPlaying
    @Published var selectedLoveSpouseProgram: Int = 1

    private var waveTimer: Timer?
    private var connectionSubscription: AnyCancellable?

    var activeDevice: SavedDevice? {
        guard let id = activeDeviceId else { return nil }
        return devices.first { $0.id == id } ?? (id == .internalDeviceID ? internalDevice : nil)
    }

    var currentPatternName: String {
        if activeDevice?.type == .lovespouse {
            let prog = selectedLoveSpouseProgram
            if prog > 0 {
                switch prog {
                case 1: return "Leicht"
                case 2: return "Mittel"
                case 3: return "Stark"
                default: return "Muster \(prog - 3)"
                }
            }
        }
        if let id = activeFunScriptId, let script = customScripts.first(where: { $0.id == id }) {
            return script.name
        }
        if activeFunScript != nil {
            return "Importiertes Script"
        }
        return selectedPreset.rawValue
    }
    
    // Stable instance for the internal device
    let internalDevice = SavedDevice(id: .internalDeviceID, name: "Phone Haptics", type: .internal)

    private var deviceSubscriptions: [UUID: AnyCancellable] = [:]

    private init() {
        self.defaultIntensity = UserDefaults.standard.double(forKey: "defaultIntensity")
        if self.defaultIntensity == 0 { self.defaultIntensity = 50 } 
        self.currentLevel = self.defaultIntensity
        
        self.strokeMin = UserDefaults.standard.double(forKey: "strokeMin")
        self.strokeMax = UserDefaults.standard.object(forKey: "strokeMax") as? Double ?? 100
        
        loadDevices()
        restoreActiveDevice()
        setupConnectionMonitoring()
        setupDeviceObservation()
    }

    private func setupDeviceObservation() {
        deviceSubscriptions.removeAll()
        for device in devices {
            let sub = device.objectWillChange
                .sink { [weak self] _ in
                    // Defer the notification so properties are updated when we react
                    DispatchQueue.main.async {
                        self?.handleDeviceChange(device)
                        self?.objectWillChange.send()
                        self?.saveDevices()
                    }
                }
            deviceSubscriptions[device.id] = sub
        }
    }

    private func handleDeviceChange(_ device: SavedDevice) {
        // If this is the active device, we need to update the managers immediately
        if device.id == activeDeviceId {
            switch device.type {
            case .handy, .oh:
                handyManager.connectionKey = device.connectionKey
            case .intiface:
                buttplugManager.serverAddress = device.serverAddress
            case .lovespouse, .internal:
                break
            }
        }
    }

    private func setupConnectionMonitoring() {
        connectionSubscription = self.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                if let device = self.activeDevice, device.isConnected {
                    // If we are playing but hardware hasn't started yet because it was offline
                    self.ensureHardwareStarted()
                }
            }
    }

    // MARK: - Device Management

    func addDevice(_ device: SavedDevice) {
        devices.append(device)
        saveDevices()
        setupDeviceObservation()
    }

    func removeDevice(_ device: SavedDevice) {
        if device.id == activeDeviceId {
            setActiveDevice(nil)
        }
        devices.removeAll { savedDevice in savedDevice.id == device.id }
        saveDevices()
        setupDeviceObservation()
    }

    func setActiveDevice(_ device: SavedDevice?, autoStart: Bool = false) {
        // Disconnect old active device if it exists
        if let currentActive = activeDevice {
            disconnectDevice(currentActive)
        }

        stop()

        activeDeviceId = device?.id
        UserDefaults.standard.set(device?.id.uuidString, forKey: "activeDeviceId")

        guard let device = device else { return }

        // Configure managers without blocking
        switch device.type {
        case .handy:
            handyManager.connectionKey = device.connectionKey
            handyManager.deviceType = "The Handy"
        case .oh:
            handyManager.connectionKey = device.connectionKey
            handyManager.deviceType = "Oh."
        case .intiface:
            buttplugManager.serverAddress = device.serverAddress
        case .lovespouse:
            objectWillChange.send()
        case .internal:
            device.isConnected = hapticManager.isSupported
            if device.isConnected {
                NSLog("🔔 DeviceManager: Internal haptics connected")
            } else {
                NSLog("🔔 DeviceManager: Internal haptics NOT supported")
            }
            objectWillChange.send()
        }
        
        // Check connection asynchronously in background
        checkDeviceConnectionAsync(device)
        
        // Auto-start playback on selection if requested
        if autoStart {
            DispatchQueue.main.async {
                self.start()
            }
        }
    }

    private func disconnectDevice(_ device: SavedDevice) {
        NSLog("🔔 DeviceManager: Disconnecting \(device.name) (\(device.type.rawValue))")
        switch device.type {
        case .handy, .oh:
            handyManager.stopMotion()
        case .intiface:
            buttplugManager.disconnect()
        case .lovespouse:
            loveSpouseManager.stopAll()
        case .internal:
            break
        }
        device.isConnected = false
        objectWillChange.send()
    }
    
    private func checkDeviceConnectionAsync(_ device: SavedDevice) {
        switch device.type {
        case .handy, .oh:
            handyManager.checkConnection { [weak self] success in
                NSLog("🔔 DeviceManager: \(device.type.rawValue) connection checked. Success: \(success)")
                DispatchQueue.main.async {
                    device.isConnected = success
                    self?.objectWillChange.send()
                }
            }
        case .intiface:
            buttplugManager.connect { [weak self] success in
                DispatchQueue.main.async {
                    device.isConnected = success
                    self?.objectWillChange.send()
                }
            }
        case .lovespouse:
            loveSpouseManager.checkConnection { [weak self] success in
                DispatchQueue.main.async {
                    device.isConnected = success
                    self?.objectWillChange.send()
                }
            }
        case .internal:
            break
        }
    }

    // MARK: - Playback

    func start() {
        guard !isPlaying else { return }
        guard activeDevice != nil else { return }

        isPlaying = true
        
        // Use default intensity if we are at 0
        if currentLevel == 0 {
            currentLevel = defaultIntensity
        }

        waveTime = 0
        
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #endif
        
        ensureHardwareStarted()
        startWaveTimer()
    }

    private func ensureHardwareStarted() {
        guard isPlaying, let device = activeDevice, device.isConnected else { return }
        
        switch device.type {
        case .handy, .oh:
            handyManager.startHamp()
        case .intiface:
            break
        case .lovespouse:
            loveSpouseManager.selectProgram(selectedLoveSpouseProgram)
        case .internal:
            hapticManager.start()
        }
    }

    func stop() {
        stopWaveTimer()
        isPlaying = false
        waveTime = 0
        funScriptPositionMs = 0
        
        if activeDevice?.type == .lovespouse {
            loveSpouseManager.stopAll()
        }
        
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
        
        hapticManager.stop()

        handyManager.stopMotion()
        buttplugManager.stopAllDevices()
        loveSpouseManager.stopAll()
        hapticManager.stop()
    }

    func setLevel(_ level: Double) {
        currentLevel = level
        
        // Intensity control via slider
        if isPlaying {
            sendLevel(level)
        }
    }

    func setStrokeRange(min: Double, max: Double) {
        let clampedMin = Swift.min(100.0, Swift.max(0.0, min))
        let clampedMax = Swift.min(100.0, Swift.max(0.0, max))

        if clampedMin >= clampedMax {
            strokeMin = clampedMax
            strokeMax = clampedMin
        } else {
            strokeMin = clampedMin
            strokeMax = clampedMax
        }

        handyManager.setSlideRange(min: strokeMin, max: strokeMax)
    }

    func applyPreset(_ preset: DeviceWavePreset) {
        selectedLoveSpouseProgram = 0 // Clear hardware program
        activeFunScript = nil
        activeFunScriptId = nil
        selectedPreset = preset

        if !isPlaying {
            start()
        }

        // Restart wave timer with new preset
        stopWaveTimer()
        waveTime = 0
        startWaveTimer()
    }


    // MARK: - FunScript

    func applyFunScript(_ script: FunScriptData) {
        selectedLoveSpouseProgram = 0 // Clear hardware program
        activeFunScript = FunScriptData(
            actions: script.actions.sorted { $0.at < $1.at },
            inverted: script.inverted,
            range: script.range
        )
        activeFunScriptId = nil
        funScriptPositionMs = 0
        if !isPlaying { start() }
        stopWaveTimer()
        waveTime = 0
        startWaveTimer()
    }

    func applyNamedFunScript(_ namedScript: NamedFunScript) {
        selectedLoveSpouseProgram = 0 // Clear hardware program
        activeFunScript = namedScript.data
        activeFunScriptId = namedScript.id
        funScriptPositionMs = 0
        if !isPlaying { start() }
        stopWaveTimer()
        waveTime = 0
        startWaveTimer()
    }

    func addCustomScript(_ script: NamedFunScript) {
        NSLog("🔔 DeviceManager: Adding custom script: \(script.name)")
        customScripts.append(script)
        saveCustomScripts()
    }

    func removeCustomScript(_ script: NamedFunScript) {
        if activeFunScriptId == script.id {
            stop()
            activeFunScript = nil
            activeFunScriptId = nil
        }
        customScripts.removeAll { $0.id == script.id }
        saveCustomScripts()
    }

    private func saveCustomScripts() {
        if let data = try? JSONEncoder().encode(customScripts) {
            UserDefaults.standard.set(data, forKey: "customScripts")
        }
    }

    // MARK: - Pattern Navigation

    func selectLoveSpouseProgram(_ index: Int) {
        guard activeDevice?.type == .lovespouse else { return }
        
        // Reset software patterns
        selectedPreset = .sine75 // Neutral state for software
        activeFunScript = nil
        activeFunScriptId = nil
        
        selectedLoveSpouseProgram = index
        
        if index > 0 {
            isPlaying = true
            loveSpouseManager.selectProgram(index)
            #if os(iOS)
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            #endif
        } else {
            stop()
        }
        objectWillChange.send()
    }

    func selectNextPattern() {
        let presets = PatternEngine.navigablePresets
        let isLS = activeDevice?.type == .lovespouse
        
        // 1. Current state: LoveSpouse Program
        if isLS && selectedLoveSpouseProgram > 0 {
            if selectedLoveSpouseProgram < 9 {
                selectLoveSpouseProgram(selectedLoveSpouseProgram + 1)
            } else {
                // End of LS Programs -> Move to first Software Preset
                selectedLoveSpouseProgram = 0
                applyPreset(presets.first ?? .sine75)
            }
            return
        }
        
        // 2. Current state: Software Preset
        if activeFunScriptId == nil {
            if let idx = presets.firstIndex(of: selectedPreset) {
                if idx < presets.count - 1 {
                    applyPreset(presets[idx + 1])
                } else if !customScripts.isEmpty {
                    // End of Presets -> Move to first Custom Script
                    applyNamedFunScript(customScripts[0])
                } else if isLS {
                    // End of Presets (no scripts) -> Back to LS Program 1
                    selectLoveSpouseProgram(1)
                } else {
                    // Loop back to first Preset
                    applyPreset(presets[0])
                }
                return
            }
        }
        
        // 3. Current state: Custom Script
        if let currentId = activeFunScriptId, let idx = customScripts.firstIndex(where: { $0.id == currentId }) {
            if idx < customScripts.count - 1 {
                applyNamedFunScript(customScripts[idx + 1])
            } else if isLS {
                // End of Scripts -> Loop back to LS Program 1
                selectLoveSpouseProgram(1)
            } else {
                // End of Scripts -> Loop back to first Software Preset
                applyPreset(presets[0])
            }
            return
        }
        
        // Fallback
        if isLS { selectLoveSpouseProgram(1) }
        else { applyPreset(presets.first ?? .sine75) }
    }

    func selectPreviousPattern() {
        let presets = PatternEngine.navigablePresets
        let isLS = activeDevice?.type == .lovespouse
        
        // 1. Current state: LoveSpouse Program
        if isLS && selectedLoveSpouseProgram > 0 {
            if selectedLoveSpouseProgram > 1 {
                selectLoveSpouseProgram(selectedLoveSpouseProgram - 1)
            } else if !customScripts.isEmpty {
                // Start of LS Programs -> Move to last Custom Script
                selectedLoveSpouseProgram = 0
                applyNamedFunScript(customScripts.last!)
            } else {
                // Start of LS Programs (no scripts) -> Move to last Software Preset
                selectedLoveSpouseProgram = 0
                applyPreset(presets.last ?? .sine75)
            }
            return
        }
        
        // 2. Current state: Software Preset
        if activeFunScriptId == nil {
            if let idx = presets.firstIndex(of: selectedPreset) {
                if idx > 0 {
                    applyPreset(presets[idx - 1])
                } else if isLS {
                    // Start of Presets -> Back to LS Program 9
                    selectLoveSpouseProgram(9)
                } else if !customScripts.isEmpty {
                    // Start of Presets -> Back to last Custom Script
                    applyNamedFunScript(customScripts.last!)
                } else {
                    // Loop back to last Preset
                    applyPreset(presets.last ?? .sine75)
                }
                return
            }
        }
        
        // 3. Current state: Custom Script
        if let currentId = activeFunScriptId, let idx = customScripts.firstIndex(where: { $0.id == currentId }) {
            if idx > 0 {
                applyNamedFunScript(customScripts[idx - 1])
            } else {
                // Start of Scripts -> Back to last Software Preset
                applyPreset(presets.last ?? .sine75)
            }
            return
        }
        
        // Fallback
        if isLS { selectLoveSpouseProgram(9) }
        else { applyPreset(presets.last ?? .sine75) }
    }

    // MARK: - Wave Pattern Engine

    private func startWaveTimer() {
        // FunScript branch: 50 Hz timer advances position through the script
        if let script = activeFunScript {
            let fsInterval: TimeInterval = (activeDevice?.type == .handy || activeDevice?.type == .oh) ? 0.1 : 0.02
            waveTimer = Timer.scheduledTimer(withTimeInterval: fsInterval, repeats: true) { [weak self] _ in
                guard let self = self, self.isPlaying else {
                    self?.stopWaveTimer()
                    return
                }
                self.funScriptPositionMs += fsInterval * 1000.0
                let duration = Double(script.durationMs)
                if duration > 0 {
                    self.funScriptPositionMs = self.funScriptPositionMs.truncatingRemainder(dividingBy: duration)
                }
                self.waveTime = self.funScriptPositionMs / 1000.0
                let pos = PatternEngine.interpolatedPos(script: script, atMs: self.funScriptPositionMs)
                var speed = pos * self.currentLevel
                
                // For internal haptics, ensure we never hit absolute 0 during a pattern to maintain motor spin
                if self.activeDevice?.type == .internal && speed < 5.0 {
                    speed = 5.0
                }
                
                self.sendLevel(speed)
            }
            return
        }

        var interval = timerInterval(for: selectedPreset)
        
        // Cloud devices (Handy, Oh) cannot handle high-frequency updates (>10Hz is risky)
        if activeDevice?.type == .handy || activeDevice?.type == .oh {
            interval = max(0.1, interval)
        }

        waveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else {
                self?.stopWaveTimer()
                return
            }

            let normalizedValue = self.calculateWaveValue(time: self.waveTime)
            var speed = self.currentLevel * normalizedValue
            
            // For internal haptics, ensure we never hit absolute 0 during a pattern to maintain motor spin
            if self.activeDevice?.type == .internal && speed < 5.0 {
                speed = 5.0
            }

            self.sendLevel(speed)
            self.waveTime += interval
        }

        // Send initial level
        sendLevel(currentLevel)
    }

    private func stopWaveTimer() {
        waveTimer?.invalidate()
        waveTimer = nil
    }

    private func sendLevel(_ level: Double) {
        guard let device = activeDevice, device.isConnected else { return }

        switch device.type {
        case .handy:
            handyManager.setHampVelocity(speed: level)
        case .oh:
            handyManager.setHampVelocity(speed: level)
        case .intiface:
            buttplugManager.setLevel(level)
        case .lovespouse:
            loveSpouseManager.setLevel(level)
        case .internal:
            hapticManager.updateIntensity(level)
        }
    }

    private func timerInterval(for preset: DeviceWavePreset) -> TimeInterval {
        switch preset {
        case .sine75:     return 0.1
        case .foreplay:   return 0.05
        case .texture:    return 0.05
        case .build1:     return 0.02   // Throb — smooth 1s cycle needs fine sampling
        case .build2:     return 0.02
        case .build3:     return 0.08
        case .climax1:    return 0.05
        case .climax2:    return 0.05
        case .aftercare:  return 0.15
        case .pulse:      return 0.05   // re-evaluate each tick; waveform is time-based
        case .wave:       return 0.05   // Wave is now 2Hz — needs faster sampling
        case .fastPulse:  return 0.05
        case .slowWave:   return 0.3
        case .ramp:       return 0.1
        case .heartbeat:  return 0.15
        case .chaos:      return 0.1
        case .tease:      return 0.2
        case .surge:      return 0.15
        case .bounce:     return 0.1
        case .breathe:    return 0.2
        case .staccato:   return 0.08
        case .thunder:    return 0.15
        case .climb:      return 0.15
        case .ocean:      return 0.2
        case .earthquake: return 0.08
        }
    }

    private func calculateWaveValue(time: Double) -> Double {
        switch selectedPreset {
        case .sine75:
            return 1.0
        case .foreplay:
            // 1s duration, rolling swell (~1Hz)
            return (sin(time * .pi * 2.0) + 1.0) / 2.0
        case .texture:
            // Rumbly, percussive texture (~6Hz)
            let base = (sin(time * .pi * 12.0) + 1.0) / 2.0
            let rumble = (sin(time * .pi * 106.0) + 1.0) / 2.0 * 0.2
            return min(1.0, base * 0.8 + rumble)
        case .build1:
            // Throb: sharp attack → brief hold → gradual decay, 1s cycle
            let cycle = time.truncatingRemainder(dividingBy: 1.0) / 1.0
            if cycle < 0.15 { return cycle / 0.15 }
            if cycle < 0.28 { return 1.0 }
            return max(0, 1.0 - (cycle - 0.28) / 0.72)
        case .build2:
            // Fast flutter (0.19s duration)
            let cycle = time.truncatingRemainder(dividingBy: 0.19) / 0.19
            return cycle < 0.5 ? 1.0 : 0.4
        case .build3:
            // Asymmetric warming
            let wave = sin(time * 6.0) + 0.4 * sin(time * 15.0)
            return (wave + 1.4) / 2.8
        case .climax1:
            let shake = sin(time * 60.0) * 0.15
            return 0.85 + shake
        case .climax2:
            let pulse = Int(time * 10) % 2 == 0 ? 1.0 : 0.7
            return pulse
        case .aftercare:
            return 0.2 + 0.1 * sin(time * 2.0)
        case .pulse:
            return Int(time / 0.5) % 2 == 0 ? 1.0 : 0.0
        case .wave:
            // 2Hz — clearly distinct from Foreplay (1Hz) and Slow Wave (~0.5Hz)
            return (sin(time * .pi * 4.0) + 1.0) / 2.0
        case .fastPulse:
            return Int(time / 0.2) % 2 == 0 ? 1.0 : 0.0
        case .slowWave:
            return (sin(time * 3.0) + 1.0) / 2.0
        case .ramp:
            // Triangle wave: 4s ramp up then 4s ramp down — no hard reset
            let cycle = time.truncatingRemainder(dividingBy: 8.0)
            return cycle < 4.0 ? cycle / 4.0 : 1.0 - ((cycle - 4.0) / 4.0)
        case .heartbeat:
            let cycle = time.truncatingRemainder(dividingBy: 1.2)
            if cycle < 0.15 { return 1.0 }
            if cycle < 0.3 { return 0.2 }
            if cycle < 0.45 { return 0.8 }
            return 0.0
        case .chaos:
            let v = (sin(time * 13.7) + sin(time * 7.3) + sin(time * 3.1)) / 3.0
            return (v + 1.0) / 2.0
        case .tease:
            let cycle = time.truncatingRemainder(dividingBy: 3.0)
            if cycle < 0.4 { return 1.0 }
            if cycle < 0.6 { return 0.5 }
            return 0.0
        case .surge:
            let cycle = time.truncatingRemainder(dividingBy: 2.0) / 2.0
            if cycle < 0.3 { return cycle / 0.3 }
            if cycle < 0.7 { return 1.0 }
            return 1.0 - ((cycle - 0.7) / 0.3)
        case .bounce:
            let cycle = time.truncatingRemainder(dividingBy: 2.0) / 2.0
            let decay = 1.0 - cycle
            return abs(sin(cycle * .pi * 6)) * decay
        case .breathe:
            let cycle = time.truncatingRemainder(dividingBy: 4.0) / 4.0
            return (1.0 - cos(cycle * .pi * 2)) / 2.0
        case .staccato:
            let cycle = time.truncatingRemainder(dividingBy: 0.3)
            return cycle < 0.08 ? 1.0 : 0.0
        case .thunder:
            let base = (sin(time * 8.0) + 1.0) / 2.0 * 0.4
            let crack = abs(sin(time * 31.0)) > 0.9 ? 1.0 : 0.0
            return min(1.0, base + crack)
        case .climb:
            let cycle = time.truncatingRemainder(dividingBy: 4.0) / 4.0
            let step = (cycle * 5.0).rounded(.down) / 5.0
            return min(1.0, step + 0.2)
        case .ocean:
            let big = (sin(time * 2.0) + 1.0) / 2.0
            let ripple = (sin(time * 11.0) + 1.0) / 2.0 * 0.2
            return min(1.0, big * 0.8 + ripple)
        case .earthquake:
            let v1 = sin(time * 17.0) * sin(time * 5.3)
            let v2 = sin(time * 11.0 + 2.0) * 0.5
            return max(0.0, min(1.0, (v1 + v2 + 1.0) / 2.0))
        }
    }

    // MARK: - Persistence

    private func restoreActiveDevice() {
        let savedIntensity = UserDefaults.standard.double(forKey: "defaultIntensity")
        self.defaultIntensity = savedIntensity > 0 ? savedIntensity : 50
        self.currentLevel = self.defaultIntensity

        // Restore saved device or default to internal haptics
        if let idString = UserDefaults.standard.string(forKey: "activeDeviceId"),
           let uuid = UUID(uuidString: idString),
           let device = devices.first(where: { $0.id == uuid }) {
            activeDeviceId = device.id
            switch device.type {
            case .handy, .oh:
                handyManager.connectionKey = device.connectionKey
                handyManager.deviceType = device.type == .handy ? "The Handy" : "Oh."
            case .intiface:
                buttplugManager.serverAddress = device.serverAddress
            case .lovespouse:
                device.isConnected = loveSpouseManager.isConnected
            case .internal:
                device.isConnected = hapticManager.isSupported
            }
        } else {
            // Default to internal haptics
            activeDeviceId = internalDevice.id
            internalDevice.isConnected = hapticManager.isSupported
        }
    }

    func saveDevices() {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: "savedDevices")
        }
    }

    private func loadDevices() {
        if let data = UserDefaults.standard.data(forKey: "savedDevices"),
           let savedDevices = try? JSONDecoder().decode([SavedDevice].self, from: data) {
            devices = savedDevices
        }
        
        // Ensure internal device is not in the saved list (handled separately)
        devices.removeAll(where: { $0.id == .internalDeviceID })

        // Load custom scripts
        if let customData = UserDefaults.standard.data(forKey: "customScripts") {
            do {
                let savedScripts = try JSONDecoder().decode([NamedFunScript].self, from: customData)
                customScripts = savedScripts
                NSLog("🔔 DeviceManager: Loaded \(customScripts.count) custom scripts")
            } catch {
                NSLog("🔔 DeviceManager: Failed to decode custom scripts: \(error)")
            }
        }

        // Restore stroke range
        if let min = UserDefaults.standard.object(forKey: "strokeMin") as? Double {
            strokeMin = min
        }
        if let max = UserDefaults.standard.object(forKey: "strokeMax") as? Double {
            strokeMax = max
        }
    }
}
