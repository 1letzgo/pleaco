//
//  VideoPlayerView.swift
//  pleaco
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: SavedVideo

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var syncManager = StashVideoSyncManager.shared
    @ObservedObject private var deviceManager = DeviceManager.shared
    @AppStorage("videoIsMuted") private var isMuted = false

    @State private var player: AVPlayer?
    @State private var isShowingFullscreen = false
    @State private var isShowingSettings = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.surfacePrimary.ignoresSafeArea()

                if let player = player {
                    Color.black
                        .frame(width: geo.size.width, height: geo.size.height)
                    PlayerViewController(player: player, gravity: .resizeAspect)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }

                // Top bar: back (left) + fullscreen + intensity (right)
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.black.opacity(0.4)))
                        }

                        Spacer()

                        AirPlayView()
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.black.opacity(0.4)))

                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.black.opacity(0.4)))
                        }

                        Button {
                            isShowingFullscreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.black.opacity(0.4)))
                        }

                        Button {
                            isShowingSettings = true
                        } label: {
                            HStack(spacing: 0) {
                                Text({
                                    switch syncManager.dominantChannel {
                                    case .hip:   return "🍑"
                                    case .head:  return "🤯"
                                    case .wrist: return "✋"
                                    }
                                }())
                                .font(.system(size: 13))
                                Spacer()
                                Text("\(Int(syncManager.currentIntensity * 100))%")
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 38, alignment: .trailing)
                            }
                            .padding(.horizontal, 10)
                            .frame(width: 88, height: 36)
                            .background(Capsule().fill(.black.opacity(0.4)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    Spacer()
                }
                .zIndex(2)


            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isShowingFullscreen) {
            if let player = player {
                FullscreenPlayerView(player: player).ignoresSafeArea()
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear {
            player?.pause()
            player = nil
            StashVideoSyncManager.shared.stop()
            DeviceManager.shared.setLevel(0)
        }
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sensitivity")
                                    .font(.caption.bold()).foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(syncManager.sensitivity * 100))%")
                                    .font(.caption.monospacedDigit()).foregroundColor(Color.appAccent)
                            }
                            Slider(value: $syncManager.sensitivity, in: 0...1).tint(Color.appAccent)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Smoothing")
                                    .font(.caption.bold()).foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(syncManager.smoothing * 100))%")
                                    .font(.caption.monospacedDigit()).foregroundColor(Color.appAccent)
                            }
                            Slider(value: $syncManager.smoothing, in: 0...1).tint(Color.appAccent)
                        }
                    }
                    Divider()
                    VStack(spacing: 12) {
                        IntensityBar(label: "Hip",      value: syncManager.hipIntensity,     color: .orange)
                        IntensityBar(label: "Pelvis",   value: syncManager.pelvisIntensity,  color: .red)
                        IntensityBar(label: "Head",     value: syncManager.headIntensity,    color: .purple)
                        IntensityBar(label: "Hands",    value: syncManager.wristIntensity,   color: .blue)
                        IntensityBar(label: "Lateral",  value: syncManager.horzIntensity,    color: .cyan)
                        Divider().padding(.vertical, 4)
                        IntensityBar(label: "Output · \({ switch syncManager.dominantChannel { case .hip: return "Hip"; case .head: return "Head"; case .wrist: return "Hand" }  }())", value: syncManager.currentIntensity, color: Color.appAccent, isMain: true)
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

    private func setupPlayer() {
        guard let url = VideoLibraryManager.shared.urlFor(video) else { return }

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = isMuted
        self.player = newPlayer

        syncManager.setup(for: playerItem, player: newPlayer, title: video.name)

        DeviceManager.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            DeviceManager.shared.start()
        }
    }
}

// MARK: - Shared UI Components

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
                        .fill(color.opacity(0.2))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
                        .animation(.linear(duration: 0.1), value: value)
                }
            }
            .frame(height: isMain ? 6 : 4)
        }
    }
}
