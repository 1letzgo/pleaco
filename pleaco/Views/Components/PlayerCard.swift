//
//  PlayerCard.swift
//  pleaco
//

import SwiftUI

// MARK: – Player Card (sticky)

struct PlayerCard: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @State private var isExpanded: Bool = false

    private var hasSliders: Bool {
        deviceManager.activeDevice?.type != .lovespouse || deviceManager.activeAudioTrack != nil
    }

    var body: some View {
        VStack(spacing: 0) { // This is the single root VStack
            HStack {
                // Program Label (Left)
                Text(deviceManager.currentPatternName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasSliders {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 0 : 180))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 8) // Doubled from 4
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                    }
                } else {
                    Spacer()
                }

                // Device Label (Right)
                Text(deviceManager.activeDevice?.name ?? "No Device")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 32) // Increased from 24
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .zIndex(2)

            // 1-3. Collapsible Slider Section
            if isExpanded && hasSliders {
                VStack(spacing: 16) {
                    // Device Specific Sliders (Integrated)
                    if deviceManager.activeDevice?.type == .handy {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.up.and.down.and.sparkles")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 24)
                            
                            RangeSlider(lowerValue: $deviceManager.strokeMin, upperValue: $deviceManager.strokeMax, range: 0...100) { editing in
                                if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                            }
                            .frame(height: 32)
                            .padding(.horizontal, 2)
                            
                            Text("\(Int(deviceManager.strokeMax))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 32, alignment: .trailing)
                        }
                    } else if deviceManager.activeDevice?.type == .ossm {
                        VStack(spacing: 16) {
                            // DEPTH
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.to.line.compact")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 24)
                                
                                Slider(value: $deviceManager.strokeMin, in: 0...100, step: 1) { editing in
                                    if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                                }
                                .tint(.white)
                                
                                Text("\(Int(deviceManager.strokeMin))%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 32, alignment: .trailing)
                            }
                            // STROKE
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.and.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 24)
                                
                                Slider(value: $deviceManager.strokeMax, in: 0...100, step: 1) { editing in
                                    if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                                }
                                .tint(.white)
                                
                                Text("\(Int(deviceManager.strokeMax))%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 32, alignment: .trailing)
                            }
                            // SENSATION
                            HStack(spacing: 12) {
                                Image(systemName: "aqi.medium")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 24)
                                
                                Slider(value: $deviceManager.ossmSensation, in: 0...100, step: 1)
                                    .tint(.white)
                                
                                Text("\(Int(deviceManager.ossmSensation))%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundColor(.white.opacity(0.6))
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
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 24)
                            
                            if isAudio {
                                Slider(value: $deviceManager.audioIntensity, in: 0...100, step: 1)
                                    .tint(.white)
                            } else {
                                Slider(value: $deviceManager.masterIntensity, in: 0...100)
                                    .tint(.white)
                            }
                            
                            Text("\(Int(isAudio ? deviceManager.audioIntensity : deviceManager.masterIntensity))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                    
                    // Audio UI (Shows only when Audio is active)
                    if deviceManager.activeAudioTrack != nil {
                        
                        // Sensitivity
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 24)
                            
                            Slider(value: $audioManager.sensitivity, in: 1...100, step: 1)
                                .tint(.white)
                            
                            Text("\(Int(audioManager.sensitivity))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 32, alignment: .trailing)
                        }
                        
                        // Time Scrubbing
                        HStack(spacing: 12) {
                            Text(formatTime(audioManager.currentTime))
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
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
                            .tint(.white)
                            
                            Text(formatTime(audioManager.duration))
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundColor(.white.opacity(0.6))
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
            
            // 4. Persistent Control Row
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Spacer()
                    // Transport (Center)
                    HStack(spacing: 24) {
                        Button { deviceManager.selectPreviousPattern() } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if deviceManager.isPlaying { deviceManager.stop() }
                            else { deviceManager.start() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 144, height: 72)
                                    .scaleEffect(deviceManager.isPlaying ? 1.0 : 0.9)
                                    .animation(deviceManager.isPlaying ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .easeOut(duration: 0.2), value: deviceManager.isPlaying)

                                RoundedRectangle(cornerRadius: Theme.cardCornerRadius - 2)
                                    .fill(Color.white)
                                    .frame(width: 132, height: 60)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

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
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
                .padding(.top, 12) // Push them down a bit more
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
