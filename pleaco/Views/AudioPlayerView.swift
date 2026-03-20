//
//  AudioPlayerView.swift
//  pleaco
//

import SwiftUI
import AVKit

struct AudioPlayerView: View {
    let track: SavedAudioTrack

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var deviceManager = DeviceManager.shared

    @State private var isShowingSettings = false
    @AppStorage("audioIsMuted") private var isMuted = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.surfacePrimary.ignoresSafeArea()

                // Live Equalizer
                AudioEqualizerView(audioManager: audioManager)
                    .frame(width: geo.size.width, height: geo.size.height)

                // Top bar: back (left) + mute (right)
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
                            audioManager.setMuted(isMuted)
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.black.opacity(0.4)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    Spacer()
                }
                .zIndex(2)

                // Bottom overlay
                VStack(spacing: 0) {
                    Spacer()
                    bottomBar
                }
                .zIndex(1)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingSettings) {
            settingsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            audioManager.setMuted(isMuted)
            if deviceManager.activeAudioTrack?.id == track.id {
                // Same track — just resume from where we left off
                if !deviceManager.isPlaying { deviceManager.start() }
            } else {
                deviceManager.applyAudioTrack(track)
            }
        }
        .onDisappear {
            AudioManager.shared.pause()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Spacer()

            Button(action: { isShowingSettings = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(Int(min(audioManager.currentAmplitude, 100)))%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .frame(width: 40, alignment: .trailing)
                }
                .foregroundColor(isShowingSettings ? Color.appAccent : Color.appAccent.opacity(0.7))
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(isShowingSettings ? Color.appAccent.opacity(0.15) : Color.cardBackground)
                        .overlay(Capsule().strokeBorder(
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
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sensitivity")
                                .font(.caption.bold()).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(audioManager.sensitivity))%")
                                .font(.caption.monospacedDigit()).foregroundColor(Color.appAccent)
                        }
                        Slider(value: $audioManager.sensitivity, in: 1...100, step: 1)
                            .tint(Color.appAccent)
                    }
                    Divider()
                    IntensityBar(
                        label: "Output Amplitude",
                        value: Float(min(audioManager.currentAmplitude, 100) / 100.0),
                        color: Color.appAccent,
                        isMain: true
                    )
                }
                .padding(20)
            }
            .navigationTitle("Audio Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingSettings = false }
                }
            }
        }
    }
}

// MARK: - Audio Equalizer Visualizer

struct AudioEqualizerView: View {
    @ObservedObject var audioManager: AudioManager

    private let barCount = 24
    private let phaseOffsets: [Double]
    private let speedFactors: [Double]

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        var phases = [Double]()
        var speeds = [Double]()
        for i in 0..<24 {
            phases.append(Double(i) * 0.41)
            speeds.append(0.7 + Double(i % 5) * 0.15)
        }
        self.phaseOffsets = phases
        self.speedFactors = speeds
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let amplitude = min(audioManager.currentAmplitude / 100.0, 1.0)

            Canvas { context, size in
                let barWidth = size.width / CGFloat(barCount)
                let gap: CGFloat = 2
                let maxH = size.height * 0.85

                for i in 0..<barCount {
                    let phase = phaseOffsets[i]
                    let speed = speedFactors[i]
                    let sine = (sin(t * speed * 3.0 + phase) + 1.0) / 2.0
                    let barH = maxH * CGFloat(amplitude) * (0.3 + 0.7 * sine)

                    let x = CGFloat(i) * barWidth + gap / 2
                    let y = size.height - barH
                    let rect = CGRect(x: x, y: y, width: barWidth - gap, height: barH)
                    let r = (barWidth - gap) / 2
                    let path = UnevenRoundedRectangle(
                        topLeadingRadius: r, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: r
                    ).path(in: rect)

                    let t_color = CGFloat(i) / CGFloat(barCount - 1)
                    let opacity = 0.5 + 0.5 * Double(amplitude)
                    context.fill(
                        path,
                        with: .color(Color.appAccent.opacity(opacity * (0.6 + 0.4 * Double(t_color))))
                    )
                }
            }
        }
        .background(Color.surfacePrimary)
    }
}
