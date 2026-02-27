//
//  SavedAudioTrack.swift
//  pleaco
//

import Foundation

struct SavedAudioTrack: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let fileName: String
}
