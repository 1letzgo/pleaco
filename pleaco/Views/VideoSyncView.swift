//
//  VideoSyncView.swift
//  pleaco
//

import SwiftUI
import AVKit
import PhotosUI

struct VideoSyncView: View {
    @ObservedObject var syncManager = StashVideoSyncManager.shared
    @ObservedObject var deviceManager = DeviceManager.shared

    @State private var player: AVPlayer?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingPicker = false
    @State private var videoURL: URL?
    @AppStorage("videoIsMuted") private var isMuted = false
    @State private var videoAspectRatio: CGFloat = 9/16   // default: portrait
    @State private var isShowingFullscreen = false
    @State private var isShowingFileImporter = false
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    @State private var isShowingSettings = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ── Background ──
                Color.surfacePrimary.ignoresSafeArea()

                // ── Video fills full area ──
                if let player = player {
                    Color.black.ignoresSafeArea()
                    PlayerViewController(player: player, gravity: .resizeAspect)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color.appAccent.opacity(0.6))
                        Text("Video Player")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // ── Bottom overlay: buttons ──
                VStack(spacing: 0) {
                    Spacer()
                    bottomBar
                }
            }
        }
        // ── Popups ──
        .sheet(isPresented: $isShowingSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if player == nil, let existingPlayer = deviceManager.activeVideoPlayer {
                player = existingPlayer
                // Restore aspect ratio from the existing player item
                if let asset = existingPlayer.currentItem?.asset as? AVURLAsset {
                    Task {
                        if let track = try? await asset.loadTracks(withMediaType: .video).first {
                            let size = try? await track.load(.naturalSize)
                            let transform = try? await track.load(.preferredTransform)
                            if let size = size, let transform = transform {
                                let rect = CGRect(origin: .zero, size: size).applying(transform)
                                let w = abs(rect.width), h = abs(rect.height)
                                if w > 0 && h > 0 {
                                    await MainActor.run { self.videoAspectRatio = w / h }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                do {
                    if let item = newValue {
                        if let movie = try await item.loadTransferable(type: VideoMovie.self) {
                            NSLog("🔵 VideoSyncView: Video loaded: \(movie.originalName)")
                            await MainActor.run {
                                self.videoURL = movie.url
                                setupPlayer(with: movie.url, title: movie.originalName)
                            }
                        }
                    }
                } catch {
                    NSLog("❌ VideoSyncView: \(error)")
                    await MainActor.run {
                        alertMessage = "Could not load video: \(error.localizedDescription)"
                        isShowingAlert = true
                    }
                }
                await MainActor.run { selectedItem = nil }
            }
        }
        .alert("Video Error", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fullScreenCover(isPresented: $isShowingFullscreen) {
            if let player = player {
                FullscreenPlayerView(player: player)
                    .ignoresSafeArea()
            }
        }
        .photosPicker(isPresented: $isShowingPicker, selection: $selectedItem, matching: .videos)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.movie, .video, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first, url.startAccessingSecurityScopedResource() {
                    do {
                        let originalName = url.deletingPathExtension().lastPathComponent
                        let localURL = try VideoMovie.copyToTemp(url: url, originalName: originalName)
                        setupPlayer(with: localURL, title: originalName)
                    } catch {
                        alertMessage = "Copy failed: \(error.localizedDescription)"
                        isShowingAlert = true
                    }
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                syncManager.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            // Choose / Change video
            Menu {
                Button(action: { isShowingPicker = true }) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                Button(action: { isShowingFileImporter = true }) {
                    Label("Files", systemImage: "folder")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: player == nil ? "plus.circle.fill" : "arrow.triangle.2.circlepath")
                    Text(player == nil ? "Select Video" : "Change")
                }
                .font(.subheadline.bold())
                .foregroundColor(Color.appAccent)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color.cardBackground)
                        .overlay(Capsule().strokeBorder(Color.subtleBorder, lineWidth: 0.5))
                )
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            if player != nil {
                // Fullscreen
                iconButton(icon: "arrow.up.left.and.arrow.down.right") {
                    isShowingFullscreen = true
                }
            }

            // Settings (Intensity + Fine-Tuning combined)
            Button(action: { isShowingSettings = true }) {
                Text("\(Int(syncManager.currentIntensity * 100))%")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundColor(isShowingSettings ? Color.appAccent : Color.appAccent.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isShowingSettings ? Color.appAccent.opacity(0.15) : Color.cardBackground)
                            .overlay(Circle().strokeBorder(
                                isShowingSettings ? Color.appAccent.opacity(0.4) : Color.subtleBorder,
                                lineWidth: 0.5))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 10)
        .background(
            player != nil
                ? AnyView(LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                : AnyView(Color.clear)
        )
    }

    @ViewBuilder
    private func iconButton(icon: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accent ? Color.appAccent : Color.appAccent.opacity(0.7))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(accent ? Color.appAccent.opacity(0.15) : Color.cardBackground)
                        .overlay(Circle().strokeBorder(
                            accent ? Color.appAccent.opacity(0.4) : Color.subtleBorder,
                            lineWidth: 0.5))
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Sheets

    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Fine-Tuning
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sensitivity")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(syncManager.sensitivity * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(Color.appAccent)
                            }
                            Slider(value: $syncManager.sensitivity, in: 0...1)
                                .tint(Color.appAccent)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Smoothing")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(syncManager.smoothing * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(Color.appAccent)
                            }
                            Slider(value: $syncManager.smoothing, in: 0...1)
                                .tint(Color.appAccent)
                        }
                    }

                    Divider()

                    // Intensity Monitors
                    VStack(spacing: 12) {
                        IntensityBar(label: "Vertical Rhythm",  value: syncManager.hipIntensity,     color: .orange)
                        IntensityBar(label: "Core Movement",    value: syncManager.pelvisIntensity,  color: .red)
                        IntensityBar(label: "Shift Tempo",      value: syncManager.headIntensity,    color: .purple)
                        IntensityBar(label: "Action Speed",     value: syncManager.wristIntensity,   color: .blue)
                        IntensityBar(label: "Lateral Boost",    value: syncManager.horzIntensity,    color: .cyan)
                        Divider().padding(.vertical, 4)
                        IntensityBar(label: "Output Intensity", value: syncManager.currentIntensity, color: Color.appAccent, isMain: true)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Video Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingSettings = false }
                }
            }
        }
    }

    // MARK: - Setup

    private func setupPlayer(with url: URL, title: String? = nil) {
        // Stop and discard the previous player before loading a new one
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil

        let asset = AVURLAsset(url: url)

        Task {
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size = size, let transform = transform {
                    let rect = CGRect(origin: .zero, size: size).applying(transform)
                    let w = abs(rect.width), h = abs(rect.height)
                    if w > 0 && h > 0 {
                        await MainActor.run { self.videoAspectRatio = w / h }
                    }
                }
            }
        }

        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = isMuted
        self.player = newPlayer

        let resolvedTitle = title ?? url.deletingPathExtension().lastPathComponent
        syncManager.setup(for: playerItem, player: newPlayer, title: resolvedTitle)

        // Stop first to reset isPlaying, then start — handles video-switch case where isPlaying is still true
        DeviceManager.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            DeviceManager.shared.start()
        }
    }
}

// MARK: - Transferable Video Model

struct VideoMovie: Transferable {
    let url: URL
    let originalName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .item) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let originalName = received.file.deletingPathExtension().lastPathComponent
            let copy = try copyToTemp(url: received.file, originalName: originalName)
            return VideoMovie(url: copy, originalName: originalName)
        }
    }

    static func copyToTemp(url: URL, originalName: String? = nil) throws -> URL {
        let ext = url.pathExtension.lowercased()
        let baseName = originalName ?? url.deletingPathExtension().lastPathComponent
        let fileName = "\(baseName).\(ext.isEmpty ? "mp4" : ext)"
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: copy.path) {
            try? FileManager.default.removeItem(at: copy)
        }
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
}

// MARK: - Custom Video Player Wrapper

struct PlayerViewController: UIViewControllerRepresentable {
    var player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = gravity
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
        uiViewController.videoGravity = gravity
    }
}

struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.activeTintColor = UIColor(Color.appAccent)
        picker.tintColor = .white
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct FullscreenPlayerView: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        return controller
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// MARK: - IntensityBar

struct IntensityBar: View {
    let label: String
    let value: Float
    let color: Color
    var isMain: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(isMain ? .caption.bold() : .system(size: 10, weight: .medium))
                    .foregroundColor(isMain ? .primary : .secondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.1))
                        .frame(height: isMain ? 8 : 4)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value), height: isMain ? 8 : 4)
                        .animation(.linear(duration: 0.1), value: value)
                }
            }
            .frame(height: isMain ? 8 : 4)
        }
    }
}
