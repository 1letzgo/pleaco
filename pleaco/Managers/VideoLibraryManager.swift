//
//  VideoLibraryManager.swift
//  pleaco
//

import Foundation
import Combine
import AVFoundation
import UIKit
import SwiftUI
import PhotosUI

struct VideoMovie: Transferable {
    let url: URL
    let originalName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let name = received.file.deletingPathExtension().lastPathComponent
            return VideoMovie(url: received.file, originalName: name)
        }
    }
}

class VideoLibraryManager: ObservableObject {
    static let shared = VideoLibraryManager()

    @Published var savedVideos: [SavedVideo] = []

    private let fileManager = FileManager.default
    private let userDefaultsKey = "savedVideos"

    private var videoDirectoryURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("VideoTracks")
    }

    private init() {
        createDirectoryIfNeeded()
        load()
    }

    // MARK: - Directory

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: videoDirectoryURL.path) {
            try? fileManager.createDirectory(at: videoDirectoryURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let videos = try? JSONDecoder().decode([SavedVideo].self, from: data) else { return }
        // Filter out entries whose files no longer exist on disk
        savedVideos = videos.filter { fileManager.fileExists(atPath: urlFor($0)?.path ?? "") }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(savedVideos) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - Public API

    func urlFor(_ video: SavedVideo) -> URL? {
        let url = videoDirectoryURL.appendingPathComponent(video.fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func importVideo(from sourceURL: URL, title: String) {
        let ext = sourceURL.pathExtension.lowercased()
        let safeName = title.isEmpty ? "Video" : title
        let fileName = "\(UUID().uuidString).\(ext.isEmpty ? "mp4" : ext)"
        let destURL = videoDirectoryURL.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            NSLog("❌ VideoLibraryManager: Copy failed: \(error)")
            return
        }

        let thumbnail = generateThumbnail(for: destURL)
        let video = SavedVideo(
            id: UUID(),
            name: safeName,
            fileName: fileName,
            thumbnailData: thumbnail
        )

        DispatchQueue.main.async {
            self.savedVideos.append(video)
            self.save()
        }
    }

    func deleteVideo(_ video: SavedVideo) {
        if let url = urlFor(video) {
            try? fileManager.removeItem(at: url)
        }
        savedVideos.removeAll { $0.id == video.id }
        save()
    }

    // MARK: - Thumbnail

    private func generateThumbnail(for url: URL) -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        // Try 2 seconds in, fallback to 0
        let times: [CMTime] = [CMTime(seconds: 2, preferredTimescale: 600),
                                CMTime(seconds: 0, preferredTimescale: 600)]
        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let uiImage = UIImage(cgImage: cgImage)
                if let data = uiImage.jpegData(compressionQuality: 0.7) {
                    return data
                }
            }
        }
        return nil
    }
}
