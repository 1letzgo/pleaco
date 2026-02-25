//
//  PlayerView.swift
//  pleaco
//

import SwiftUI

struct PlayerView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                artworkSection
                
                infoSection
                
                intensitySection
                
                transportControls
                
                deviceStatusSection
                
                strokeRangeSection
                
                Spacer(minLength: 40)
            }
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }
    
    private var artworkSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
            
            MiniWaveformPreview()
                .padding(24)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 36)
        .padding(.top, 20)
        .shadow(color: .black.opacity(0.3), radius: 32, x: 0, y: 16)
    }
    
    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(deviceManager.currentPatternName)
                .font(.title.bold())
                .lineLimit(1)

            Text(deviceManager.activeDevice?.name ?? "No Device Connected")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var intensitySection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Intensity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(deviceManager.currentLevel))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $deviceManager.currentLevel, in: 0...100) { editing in
                if !editing { deviceManager.setLevel(deviceManager.currentLevel) }
            }
            .tint(Color.appAccent)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }
    
    private var transportControls: some View {
        HStack(spacing: 48) {
            Button {
                deviceManager.selectPreviousPattern()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.primary)
            }

            Button {
                if deviceManager.isPlaying {
                    deviceManager.stop()
                } else {
                    deviceManager.start()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.glowAccent, radius: 16, x: 0, y: 8)

                    Image(systemName: deviceManager.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Button {
                deviceManager.selectNextPattern()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.92))
        .padding(.vertical, 8)
    }
    
    private var deviceStatusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(deviceManager.activeDevice?.isConnected == true ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(deviceManager.activeDevice?.isConnected == true ? "Connected" : "Not Connected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .animation(.easeInOut(duration: 0.2), value: deviceManager.activeDevice?.isConnected)
    }
    
    @ViewBuilder
    private var strokeRangeSection: some View {
        if deviceManager.activeDevice?.type == .handy {
            VStack(spacing: 16) {
                HStack {
                    Label("Stroke Range", systemImage: "arrow.left.and.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(deviceManager.strokeMin))–\(Int(deviceManager.strokeMax))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                RangeSlider(
                    lowerValue: $deviceManager.strokeMin,
                    upperValue: $deviceManager.strokeMax,
                    range: 0...100
                ) { editing in
                    if !editing {
                        deviceManager.setStrokeRange(
                            min: deviceManager.strokeMin,
                            max: deviceManager.strokeMax
                        )
                    }
                }
                .frame(height: 36)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
        }
    }
}
