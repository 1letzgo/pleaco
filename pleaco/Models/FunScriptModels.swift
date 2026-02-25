//
//  FunScriptModels.swift
//  pleaco
//

import Foundation
import SwiftUI

enum PatternGroup: String, CaseIterable {
    case custom = "Lokal"
    case reactive = "Reaktiv"
    case gentle = "Gentle"
    case rhythmic = "Rhythmic"
    case intense = "Intense"
    
    var presets: [DeviceWavePreset] {
        switch self {
        case .custom, .reactive: return []
        case .gentle:
            return [.sine75, .foreplay, .texture, .slowWave, .aftercare, .ramp, .ocean, .climb]
        case .rhythmic:
            return [.build1, .pulse, .fastPulse, .wave, .heartbeat, .bounce, .breathe, .staccato, .tease]
        case .intense:
            return [.build2, .build3, .climax1, .climax2, .chaos, .surge, .thunder, .earthquake]
        }
    }
}

struct FunScriptData: Codable {
    struct Action: Codable {
        let at: Int // time in ms
        let pos: Int // position 0-100
    }

    let actions: [Action]
    let inverted: Bool
    let range: Int

    var durationMs: Int {
        actions.last?.at ?? 0
    }

    // Memberwise init for manual construction
    init(actions: [Action] = [], inverted: Bool = false, range: Int = 100) {
        self.actions = actions
        self.inverted = inverted
        self.range = range
    }

    // Custom decoding: `inverted` and `range` are optional in many real-world
    // .funscript files — default to false / 100 when absent.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actions  = try container.decode([Action].self, forKey: .actions)
        inverted = (try? container.decodeIfPresent(Bool.self, forKey: .inverted)) ?? false
        range    = (try? container.decodeIfPresent(Int.self,  forKey: .range))    ?? 100
    }

    enum CodingKeys: String, CodingKey {
        case actions, inverted, range
    }
}

struct NamedFunScript: Codable, Identifiable {
    let id: UUID
    let name: String
    let data: FunScriptData
    
    init(id: UUID = UUID(), name: String, data: FunScriptData) {
        self.id = id
        self.name = name
        self.data = data
    }
}
