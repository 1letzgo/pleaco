//
//  MediaView.swift
//  pleaco
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MediaView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var deviceManager = DeviceManager.shared
    @ObservedObject private var videoLibrary = VideoLibraryManager.shared

    // Audio import
    @State private var isShowingAudioPicker = false

    // Video import
    @State private var isShowingVideoPicker = false
    @State private var isShowingVideoImporter = false
    @State private var selectedVideoItem: PhotosPickerItem?

    // Alert
    @State private var alertMessage = ""
    @State private var isShowingAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    audioSection
                    videoSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
            }
            .contentMargins(.bottom, 20, for: .scrollContent)
            .background(Color.surfacePrimary)
            .navigationBarHidden(true)
        }
        // Audio picker sheet
        #if os(iOS)
        .sheet(isPresented: $isShowingAudioPicker) {
            AudioDocumentPicker { url in
                guard url.startAccessingSecurityScopedResource() else { return }
                let tempDir = FileManager.default.temporaryDirectory
                let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    url.stopAccessingSecurityScopedResource()
                    audioManager.importTrack(from: targetURL)
                } catch {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        #endif
        // Video file importer
        .fileImporter(
            isPresented: $isShowingVideoImporter,
            allowedContentTypes: [.movie, .video, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
                let title = url.deletingPathExtension().lastPathComponent
                videoLibrary.importVideo(from: url, title: title)
                url.stopAccessingSecurityScopedResource()
            case .failure(let error):
                alertMessage = error.localizedDescription
                isShowingAlert = true
            }
        }
        // Video photos picker
        .photosPicker(isPresented: $isShowingVideoPicker, selection: $selectedVideoItem, matching: .videos)
        .onChange(of: selectedVideoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let movie = try? await newItem.loadTransferable(type: VideoMovie.self) {
                    videoLibrary.importVideo(from: movie.url, title: movie.originalName)
                }
                await MainActor.run { selectedVideoItem = nil }
            }
        }
        .alert("Import Error", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Audio", icon: "music.note.list")
                Spacer()
                Button {
                    isShowingAudioPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.appAccent)
                }
            }

            if audioManager.savedTracks.isEmpty {
                emptyState(icon: "music.note.list", text: "No tracks imported yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(audioManager.savedTracks) { track in
                        audioTrackRow(track)
                    }
                }
            }
        }
    }

    private func audioTrackRow(_ track: SavedAudioTrack) -> some View {
        return NavigationLink(destination: AudioPlayerView(track: track)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.surfaceSecondary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(Color.appAccent)
                }
                Text(track.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .appCardStyle()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                audioManager.deleteTrack(track)
                if deviceManager.activeAudioTrack?.id == track.id {
                    deviceManager.stop()
                    deviceManager.activeAudioTrack = nil
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Video Section

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Video", icon: "video")
                Spacer()
                Menu {
                    Button(action: { isShowingVideoPicker = true }) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    Button(action: { isShowingVideoImporter = true }) {
                        Label("Files", systemImage: "folder")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Color.appAccent)
                }
                .buttonStyle(.plain)
            }

            if videoLibrary.savedVideos.isEmpty {
                emptyState(icon: "video", text: "No videos imported yet.")
            } else {
                VStack(spacing: 8) {
                    ForEach(videoLibrary.savedVideos) { video in
                        videoRow(video)
                    }
                }
            }
        }
    }

    private func videoRow(_ video: SavedVideo) -> some View {
        return NavigationLink(destination: VideoPlayerView(video: video)) {
            HStack(spacing: 14) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.surfaceSecondary)
                        .frame(width: 80, height: 45)
                    if let data = video.thumbnailData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 45)
                            .clipped()
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: 18))
                            .foregroundColor(Color.appAccent.opacity(0.5))
                    }
                }

                Text(video.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .appCardStyle()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                if deviceManager.activeVideoTitle == video.name {
                    deviceManager.stop()
                }
                videoLibrary.deleteVideo(video)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Color.appAccent.opacity(0.5))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .appCardStyle()
    }
}

// MARK: - Audio Document Picker

#if os(iOS)
struct AudioDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.mp3, .wav, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: AudioDocumentPicker
        init(_ parent: AudioDocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}
#endif
