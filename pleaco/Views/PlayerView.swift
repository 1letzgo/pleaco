//
//  PlayerView.swift
//  pleaco
//

import SwiftUI

struct PlayerView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    // Artwork / Waveform area - Apple Music Style
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.appContrast.opacity(0.05))
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        VStack {
                            MiniWaveformPreview()
                                .frame(height: 180)
                                .padding()
                        }
                    }
                    .frame(width: geometry.size.width - 64, height: geometry.size.width - 64)
                    .padding(.top, 20)
                    
                    // Info
                    VStack(spacing: 4) {
                        Text(deviceManager.currentPatternName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        
                        Text(deviceManager.activeDevice?.name ?? "No Device Connected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Progress Bar (Visual only - shows current intensity)
                    // Intensity Slider
                    VStack(spacing: 4) {
                        Slider(value: $deviceManager.currentLevel, in: 0...100) { editing in
                            if !editing { deviceManager.setLevel(deviceManager.currentLevel) }
                        }
                        .tint(Color.accentColor)
                        
                        Text("\(Int(deviceManager.currentLevel))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 32)
                    
                    // Controls - Apple Music Style
                    HStack(spacing: 48) {
                        Button(action: {
                            deviceManager.selectPreviousPattern()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 32, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            if deviceManager.isPlaying {
                                deviceManager.stop()
                            } else {
                                deviceManager.start()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 72, height: 72)
                                
                                Image(systemName: deviceManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            deviceManager.selectNextPattern()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 32, weight: .medium))
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.vertical, 8)
                    
                    // Device Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(deviceManager.activeDevice?.isConnected == true ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(deviceManager.activeDevice?.isConnected == true ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Stroke Range (The Handy only)
                    if deviceManager.activeDevice?.type == .handy {
                        VStack(spacing: 12) {
                            HStack {
                                Label("Stroke Range", systemImage: "arrow.left.and.right")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(deviceManager.strokeMin))% - \(Int(deviceManager.strokeMax))%")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 32)
                            
                            RangeSlider(
                                lowerValue: $deviceManager.strokeMin,
                                upperValue: $deviceManager.strokeMax,
                                range: 0...100,
                                onEditingChanged: { editing in
                                    if !editing {
                                        deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax)
                                    }
                                }
                            )
                            .frame(height: 32)
                            .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 16)
                        .background(Color.appContrast.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .background(Color.appBackground)
    }
}
