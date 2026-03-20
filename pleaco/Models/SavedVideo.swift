//
//  SavedVideo.swift
//  pleaco
//

import Foundation

struct SavedVideo: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let fileName: String        // relative to Documents/VideoTracks/
    var thumbnailData: Data?    // JPEG thumbnail generated at import

    static func == (lhs: SavedVideo, rhs: SavedVideo) -> Bool {
        lhs.id == rhs.id
    }
}
