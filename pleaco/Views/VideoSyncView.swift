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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Video Player Section
                videoPlayerSection
                
                // Intensity Monitors
                intensityMonitorSection
                
                // Sensitivity/Smoothing Controls (Still useful for fine-tuning)
                fineTuningSection
                
                Spacer(minLength: 40)
            }
            .padding(.top, 20)
        }
        .background(Color.surfacePrimary)
        .onDisappear {
            syncManager.stop()
            player?.pause()
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mov")
                    try? data.write(to: tempURL)
                    await MainActor.run {
                        self.videoURL = tempURL
                        setupPlayer(with: tempURL)
                    }
                }
            }
        }
    }
    
    // MARK: - Subcomponents
    
    private var videoPlayerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .fill(Color.cardBackground)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )
                
                if let player = player {
                    // Custom player without native controls
                    PlayerViewController(player: player)
                        .cornerRadius(Theme.cardCornerRadius)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(Color.appAccent.opacity(0.6))
                        
                        Text("Select Video")
                            .font(.headline)
                    }
                }
            }
            .padding(.horizontal, 20)
            .onTapGesture {
                isShowingPicker = true
            }
            
            PhotosPicker(selection: $selectedItem, matching: .videos) {
                Label("Choose Video", systemImage: "photo.on.rectangle")
                    .font(.subheadline.bold())
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(Color.surfaceSecondary))
                    .overlay(Capsule().strokeBorder(Color.subtleBorder, lineWidth: 0.5))
            }
        }
    }
    
    private var fineTuningSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Fine-Tuning", icon: "slider.horizontal.3")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Sensitivity
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
                
                // Smoothing
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
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }
    
    private var intensityMonitorSection: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Intensity Monitors", icon: "waveform.path.ecg")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                IntensityBar(label: "Vertical Rhythm", value: syncManager.hipIntensity, color: .orange)
                IntensityBar(label: "Core Movement", value: syncManager.pelvisIntensity, color: .red)
                IntensityBar(label: "Shift Tempo", value: syncManager.headIntensity, color: .purple)
                IntensityBar(label: "Action Speed", value: syncManager.wristIntensity, color: .blue)
                IntensityBar(label: "Lateral Motion", value: syncManager.horzIntensity, color: .cyan)
                
                Divider()
                    .padding(.vertical, 4)
                
                IntensityBar(label: "Output Intensity", value: syncManager.currentIntensity, color: Color.appAccent, isMain: true)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Methods
    
    private func setupPlayer(with url: URL) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)
        self.player = newPlayer
        
        // Pass both item and player to sync manager
        syncManager.setup(for: playerItem, player: newPlayer)
    }
}

// MARK: - Custom Video Player Wrapper

struct PlayerViewController: UIViewControllerRepresentable {
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide all native controls
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// MARK: - Subcomponents

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
