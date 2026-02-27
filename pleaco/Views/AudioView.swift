//
//  AudioView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

struct AudioView: View {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var deviceManager = DeviceManager.shared
    @State private var showingAudioPicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Area
                    headerSection

                    // Tracks List Area
                    tracksSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .contentMargins(.bottom, 180, for: .scrollContent)
            .scrollClipDisabled()

            // Reusing the same Player Card from Home
            PlayerCard()
        }
        .background(Color.surfacePrimary)
        #if os(iOS)
        .sheet(isPresented: $showingAudioPicker) {
            AudioDocumentPicker { url in
                guard url.startAccessingSecurityScopedResource() else {
                    print("Could not access security scoped resource for audio file.")
                    return
                }
                
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
                    print("Error copying file: \(error.localizedDescription)")
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        #endif
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
            
            // Reactive background bloom
            if audioManager.isPlaying && deviceManager.activeAudioTrack != nil {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        RadialGradient(
                            colors: [Color.appAccent.opacity(0.1 + (audioManager.currentAmplitude / 200.0)), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 160
                        )
                    )
                    .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8, blendDuration: 0.3), value: audioManager.currentAmplitude)
            }

            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(Color.appAccent.opacity(0.7))
                    // Pulse the icon slightly based on the audio amplitude
                    .scaleEffect(audioManager.isPlaying && deviceManager.activeAudioTrack != nil ? 1.0 + (audioManager.currentAmplitude / 300.0) : 1.0)
                    .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: audioManager.currentAmplitude)
                
                Text("Audio to Vibration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }

    private var tracksSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Library")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    showingAudioPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Import")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(Color.appAccent)
                }
            }

            if audioManager.savedTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(Color.appAccent.opacity(0.5))
                    Text("No tracks imported yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardBackground))
            } else {
                ForEach(audioManager.savedTracks) { track in
                    trackRow(for: track)
                }
            }
        }
    }

    private func trackRow(for track: SavedAudioTrack) -> some View {
        let isSelected = deviceManager.activeAudioTrack?.id == track.id
        
        return Button {
            audioManager.loadTrack(track)
            deviceManager.applyAudioTrack(track)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.surfaceSecondary))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isSelected && audioManager.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : Color.appAccent)
                }
                
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AnyShapeStyle(Color.appAccent.opacity(0.1)) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.appAccent.opacity(0.5) : Color.subtleBorder, lineWidth: 1)
            )
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
}

// MARK: - Audio Document Picker

#if os(iOS)
struct AudioDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Support common audio formats
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
