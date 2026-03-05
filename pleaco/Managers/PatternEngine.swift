//
//  PatternEngine.swift
//  pleaco
//

import Foundation

class PatternEngine {
    static let navigablePresets: [DeviceWavePreset] = DeviceWavePreset.allCases
    
    static var cachedCurves: [DeviceWavePreset: [Double]] {
        var curves: [DeviceWavePreset: [Double]] = [:]
        for preset in navigablePresets {
            curves[preset] = samplePreset(preset, points: 60)
        }
        return curves
    }
    
    static func interpolatedPos(script: FunScriptData, atMs ms: Double) -> Double {
        guard !script.actions.isEmpty else { return 0 }
        
        let actions = script.actions
        if ms <= Double(actions[0].at) { return Double(actions[0].pos) / 100.0 }
        if ms >= Double(actions.last!.at) { return Double(actions.last!.pos) / 100.0 }
        
        // Find surrounding actions
        for i in 0..<actions.count - 1 {
            let a1 = actions[i]
            let a2 = actions[i+1]
            if ms >= Double(a1.at) && ms <= Double(a2.at) {
                let span = Double(a2.at - a1.at)
                let progress = (ms - Double(a1.at)) / span
                let pos = Double(a1.pos) + progress * Double(a2.pos - a1.pos)
                return pos / 100.0
            }
        }
        return 0
    }
    
    static func sampleFunScriptCurve(_ script: FunScriptData, pointCount: Int) -> [Double] {
        guard pointCount > 0 else { return [] }
        let duration = Double(script.durationMs)
        var points: [Double] = []
        for i in 0..<pointCount {
            let atMs = (Double(i) / Double(pointCount - 1)) * duration
            points.append(interpolatedPos(script: script, atMs: atMs))
        }
        return points
    }
    
    private static func samplePreset(_ preset: DeviceWavePreset, points: Int) -> [Double] {
        var values: [Double] = []
        // We'll use a 2 second window for previews
        let duration = 2.0
        for i in 0..<points {
            let t = (Double(i) / Double(points - 1)) * duration
            values.append(generateValue(preset, time: t))
        }
        return values
    }
    
    static func generateValue(_ preset: DeviceWavePreset, time: Double) -> Double {
        switch preset {
        case .low:        return 0.3
        case .medium:     return 0.6
        case .high:       return 1.0
        case .foreplay:   return (sin(time * .pi * 2.0) + 1.0) / 2.0
        case .texture:
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
            let cycle = time.truncatingRemainder(dividingBy: 0.19) / 0.19
            return cycle < 0.5 ? 1.0 : 0.4
        case .build3:
            let wave = sin(time * 6.0) + 0.4 * sin(time * 15.0)
            return (wave + 1.4) / 2.8
        case .climax1:
            let shake = sin(time * 60.0) * 0.15
            return 0.85 + shake
        case .climax2:    return Int(time * 10) % 2 == 0 ? 1.0 : 0.7
        case .aftercare:  return 0.2 + 0.1 * sin(time * 2.0)
        case .pulse:      return Int(time / 0.5) % 2 == 0 ? 1.0 : 0.0
        case .wave:       return (sin(time * .pi * 4.0) + 1.0) / 2.0  // 2Hz
        case .fastPulse:  return Int(time / 0.2) % 2 == 0 ? 1.0 : 0.0
        case .slowWave:   return (sin(time * 3.0) + 1.0) / 2.0
        case .ramp:
            // Triangle wave: 4s ramp up, 4s ramp down — no hard reset
            let rampCycle = time.truncatingRemainder(dividingBy: 8.0)
            return rampCycle < 4.0 ? rampCycle / 4.0 : 1.0 - ((rampCycle - 4.0) / 4.0)
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
}
