//
//  PlayerCard.swift
//  pleaco
//

import SwiftUI

// MARK: – Player Card (sticky)

struct PlayerCard: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // 1. Device Specific Sliders (Integrated)
            if deviceManager.activeDevice?.type == .handy {
                VStack(spacing: 4) {
                    HStack {
                        Text("HB RANGE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(deviceManager.strokeMin))% - \(Int(deviceManager.strokeMax))%")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                    }
                    RangeSlider(lowerValue: $deviceManager.strokeMin, upperValue: $deviceManager.strokeMax, range: 0...100) { editing in
                        if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                    }
                    .frame(height: 20)
                }
            } else if deviceManager.activeDevice?.type == .ossm {
                VStack(spacing: 8) {
                    // DEPTH
                    VStack(spacing: 4) {
                        HStack {
                            Text("DEPTH")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int(deviceManager.strokeMin))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                        }
                        Slider(value: $deviceManager.strokeMin, in: 0...100, step: 1) { editing in
                            if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                        }
                        .tint(.white)
                    }

                    // STROKE
                    VStack(spacing: 4) {
                        HStack {
                            Text("STROKE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int(deviceManager.strokeMax))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                        }
                        Slider(value: $deviceManager.strokeMax, in: 0...100, step: 1) { editing in
                            if !editing { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                        }
                        .tint(.white)
                    }
                    
                    // SENSATION
                    VStack(spacing: 4) {
                        HStack {
                            Text("SENSATION")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int(deviceManager.ossmSensation))%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                        }
                        Slider(value: $deviceManager.ossmSensation, in: 0...100, step: 1)
                            .tint(.white)
                    }
                }
            }

            // 2. Generic Intensity
            if deviceManager.activeDevice?.type != .lovespouse {
                VStack(spacing: 4) {
                    HStack {
                        Text("INTENSITY")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(deviceManager.currentLevel))%")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                    }
                    Slider(value: $deviceManager.currentLevel, in: 0...100) { editing in
                        if !editing { deviceManager.setLevel(deviceManager.currentLevel) }
                    }
                    .tint(.white)
                }
                Spacer().frame(height: 8)
            }
            
            // 3. Audio UI (Shows only when Audio is active)
            if deviceManager.activeAudioTrack != nil {
                @ObservedObject var audioManager = AudioManager.shared
                
                // Sensitivity
                VStack(spacing: 4) {
                    HStack {
                        Text("AUDIO SENSITIVITY")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(audioManager.sensitivity))%")
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                    }
                    Slider(value: $audioManager.sensitivity, in: 1...100, step: 1)
                        .tint(.white)
                }
                
                // Time Scrubbing
                VStack(spacing: 4) {
                    HStack {
                        Text(formatTime(audioManager.currentTime))
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(formatTime(audioManager.duration))
                            .font(.system(size: 10, weight: .bold).monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Slider(value: Binding(
                        get: { audioManager.currentTime },
                        set: { audioManager.seek(to: $0) }
                    ), in: 0...max(1, audioManager.duration))
                    .tint(.white)
                }
                Spacer().frame(height: 4)
            }

            // 4. Control Row: PROGRAM << PLAY >> DEVICENAME
            HStack(alignment: .center) {
                // Program Label (Left)
                Text(deviceManager.currentPatternName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 90, alignment: .leading)

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
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 78, height: 78)
                                .scaleEffect(deviceManager.isPlaying ? 1.0 : 0.8)
                                .animation(deviceManager.isPlaying ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .easeOut(duration: 0.2), value: deviceManager.isPlaying)

                            Circle()
                                .fill(Color.white)
                                .frame(width: 66, height: 66)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                            Image(systemName: deviceManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color.appAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(deviceManager.activeDevice?.isConnected == true ? 1 : 0.6)

                    Button { deviceManager.selectNextPattern() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Device Label (Right)
                Text(deviceManager.activeDevice?.name ?? "No Device")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 90, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 4)
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
    }
    
    // Helper function
    private func formatTime(_ time: TimeInterval) -> String {
        guard time > 0 else { return "0:00" }
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}
