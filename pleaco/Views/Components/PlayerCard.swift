//
//  PlayerCard.swift
//  pleaco
//

import SwiftUI
import AVKit

// MARK: – Player Card (sticky)

struct PlayerCard: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject private var audioManager = AudioManager.shared
    @ObservedObject private var syncManager = StashVideoSyncManager.shared
    @State private var isExpanded: Bool = false
    @AppStorage("videoIsMuted") private var isMuted = false

    private var hasSliders: Bool {
        deviceManager.activeDevice?.type != .lovespouse || deviceManager.activeAudioTrack != nil
    }

    var body: some View {
        VStack(spacing: 0) { // This is the single root VStack

            // 1-3. Collapsible Slider Section
            if isExpanded && hasSliders {
                VStack(spacing: 16) {
                    // Device Specific Sliders (Integrated)
                    if deviceManager.activeDevice?.type == .handy {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.and.down.and.sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 24)
                            
                            RangeSlider(lowerValue: $deviceManager.strokeMin, upperValue: $deviceManager.strokeMax, range: 0...100) { editing in
                                if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                            }
                            .frame(height: 32)
                            .padding(.horizontal, 2)
                            
                            Text("\(Int(deviceManager.strokeMax))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .trailing)
                        }
                    } else if deviceManager.activeDevice?.type == .ossm {
                        VStack(spacing: 16) {
                            // DEPTH
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.appAccent.opacity(0.7))
                                    .frame(width: 24)
                                
                                Slider(value: $deviceManager.strokeMin, in: 0...100, step: 1) { editing in
                                    if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                                }
                                .tint(Color.appAccent)
                                
                                Text("\(Int(deviceManager.strokeMin))%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(Color.appAccent.opacity(0.7))
                                    .frame(width: 32, alignment: .trailing)
                            }
                            // STROKE
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.and.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.appAccent.opacity(0.7))
                                    .frame(width: 24)
                                
                                Slider(value: $deviceManager.strokeMax, in: 0...100, step: 1) { editing in
                                    if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                                }
                                .tint(Color.appAccent)
                                
                                Text("\(Int(deviceManager.strokeMax))%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(Color.appAccent.opacity(0.7))
                                    .frame(width: 32, alignment: .trailing)
                            }
                            // SENSATION
                            HStack(spacing: 12) {
                                Image(systemName: "aqi.medium")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.appAccent.opacity(0.7))
                                    .frame(width: 24)
                                
                                Slider(value: $deviceManager.ossmSensation, in: 0...100, step: 1)
                                    .tint(Color.appAccent)
                                
                                Text("\(Int(deviceManager.ossmSensation))%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(Color.appAccent.opacity(0.7))
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }

                    // Generic Intensity / Multi-mode Limit
                    if deviceManager.activeDevice?.type != .lovespouse {
                        let isAudio = deviceManager.activeAudioTrack != nil
                        HStack(spacing: 12) {
                            Image(systemName: isAudio ? "bolt.horizontal.icloud.fill" : "bolt.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 24)
                            
                            if isAudio {
                                Slider(value: $deviceManager.audioIntensity, in: 0...100, step: 1)
                                    .tint(Color.appAccent)
                            } else {
                                Slider(value: $deviceManager.masterIntensity, in: 0...100)
                                    .tint(Color.appAccent)
                            }
                            
                            Text("\(Int(isAudio ? deviceManager.audioIntensity : deviceManager.masterIntensity))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                    
                    // Video scrubber (shows only when Video is active)
                    if deviceManager.activeVideoPlayer != nil {
                        HStack(spacing: 12) {
                            Text(formatTime(syncManager.videoCurrentTime))
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .leading)

                            Slider(
                                value: Binding(
                                    get: { syncManager.videoCurrentTime },
                                    set: { syncManager.videoCurrentTime = $0 }
                                ),
                                in: 0...max(1, syncManager.videoDuration)
                            ) { editing in
                                if editing {
                                    syncManager.isScrubbing = true
                                } else {
                                    syncManager.seekVideo(to: syncManager.videoCurrentTime)
                                }
                            }
                            .tint(Color.appAccent)

                            Text(formatTime(syncManager.videoDuration))
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }

                    // Audio UI (Shows only when Audio is active)
                    if deviceManager.activeAudioTrack != nil {
                        
                        // Sensitivity
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 24)
                            
                            Slider(value: $audioManager.sensitivity, in: 1...100, step: 1)
                                .tint(Color.appAccent)
                            
                            Text("\(Int(audioManager.sensitivity))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .trailing)
                        }
                        
                        // Time Scrubbing
                        HStack(spacing: 12) {
                            Text(formatTime(audioManager.currentTime))
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .leading)
                            
                            Slider(
                                value: Binding(
                                    get: { audioManager.currentTime },
                                    set: { newValue in
                                        audioManager.currentTime = newValue
                                    }
                                ),
                                in: 0...max(1, audioManager.duration)
                            ) { editing in
                                if !editing {
                                    audioManager.seek(to: audioManager.currentTime)
                                } else {
                                    audioManager.pauseTimeObserver()
                                }
                            }
                            .tint(Color.appAccent)
                            
                            Text(formatTime(audioManager.duration))
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(Color.appAccent.opacity(0.7))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(0)
            }
            
            // Persistent Control Row
            VStack(spacing: 0) {
                // Info line: program name (left) · device name (right)
                HStack {
                    Text(deviceManager.currentPatternName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.appAccent.opacity(0.6))
                        .lineLimit(1)
                    Spacer()
                    Text(deviceManager.activeDevice?.name ?? "No Device")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.appAccent.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 2)

                // Transport row: chevron (left) | ⏮ ▶ ⏭ (center) | balance spacer (right)
                HStack(alignment: .center) {
                    // Expand/collapse chevron
                    if hasSliders {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appAccent.opacity(0.5))
                                .frame(width: 36, height: 36)
                                .background(Color.appAccent.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }

                    Spacer()

                    HStack(spacing: 24) {
                        Button { deviceManager.selectPreviousPattern() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.appAccent)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if deviceManager.isPlaying { deviceManager.stop() }
                            else { deviceManager.start() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                    .fill(Color.appAccent.opacity(0.2))
                                    .frame(width: 144, height: 72)
                                    .scaleEffect(deviceManager.isPlaying ? 1.0 : 0.9)
                                    .animation(deviceManager.isPlaying ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .easeOut(duration: 0.2), value: deviceManager.isPlaying)

                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius - 2)
                                    .fill(Color.white)
                                    .frame(width: 132, height: 60)
                                    .shadow(color: Color.appAccent.opacity(0.3), radius: 10, x: 0, y: 5)

                                Image(systemName: deviceManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color.appAccent)
                            }
                        }
                        .buttonStyle(.plain)
                        .opacity(deviceManager.activeDevice?.isConnected == true ? 1 : 0.6)
                        .disabled(deviceManager.activeDevice?.isConnected != true)

                        Button { deviceManager.selectNextPattern() } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.appAccent)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
                .padding(.top, 4)
            }
            .background(Color.footerBackground)
            .zIndex(1)
        }
        .foregroundColor(.white)
        .background(
            Color.footerBackground // Unified color matching cards
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: -4)
                .overlay(alignment: .top) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                }
        )
        .animation(.easeInOut(duration: 0.4), value: deviceManager.isPlaying)
        .onChange(of: deviceManager.activeDeviceId) { oldVal, newVal in
            isExpanded = false
        }
        .onChange(of: deviceManager.activeAudioTrack) { oldVal, newVal in
            isExpanded = false
        }
    }
    
    // Helper function
    private func formatTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "0:00" }
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - AirPlay button styled for the dark footer

private struct AVRoutePickerView_PlayerCard: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.activeTintColor = UIColor(Color.appAccent)
        picker.tintColor = UIColor(Color.appAccent.opacity(0.6))
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
