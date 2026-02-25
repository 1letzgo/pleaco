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

                if deviceManager.activeDevice?.type != .lovespouse {
                    intensitySection
                }

                transportControls

                deviceStatusSection

                strokeRangeSection

                Spacer(minLength: 40)
            }
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }

    // MARK: – Artwork

    private var artworkSection: some View {
        ZStack {
            // Warm card background
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )

            // Soft bloom vignette when playing
            if deviceManager.isPlaying {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(
                            colors: [Color.appAccent.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 160
                        )
                    )
                    .animation(.easeInOut(duration: 1.2), value: deviceManager.isPlaying)
            }

            MiniWaveformPreview()
                .padding(28)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 36)
        .padding(.top, 20)
        .shadow(color: .black.opacity(0.28), radius: 36, x: 0, y: 18)
    }

    // MARK: – Info

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(deviceManager.currentPatternName)
                .font(.title.bold())
                .lineLimit(1)

            Text(deviceManager.activeDevice?.name ?? "Kein Gerät verbunden")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: – Intensity

    private var intensitySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Intensität")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(deviceManager.currentLevel))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            // Rose gradient slider
            Slider(value: $deviceManager.currentLevel, in: 0...100) { editing in
                if !editing { deviceManager.setLevel(deviceManager.currentLevel) }
            }
            .tint(Color.appAccent)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }

    // MARK: – Transport Controls

    private var transportControls: some View {
        HStack(spacing: 52) {
            Button {
                deviceManager.selectPreviousPattern()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Play / Pause button with bloom
            Button {
                if deviceManager.isPlaying {
                    deviceManager.stop()
                } else {
                    deviceManager.start()
                }
            } label: {
                ZStack {
                    // Outer bloom ring
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 96, height: 96)
                        .scaleEffect(deviceManager.isPlaying ? 1.0 : 0.85)
                        .animation(
                            deviceManager.isPlaying
                                ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                                : .easeOut(duration: 0.3),
                            value: deviceManager.isPlaying
                        )

                    Circle()
                        .fill(LinearGradient.accentGradient)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.glowAccent, radius: 22, x: 0, y: 10)

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

    // MARK: – Device Status

    private var deviceStatusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(deviceManager.activeDevice?.isConnected == true ? Color.appAccent.opacity(0.85) : Color.gray)
                .frame(width: 8, height: 8)

            Text(deviceManager.activeDevice?.isConnected == true ? "Verbunden" : "Nicht verbunden")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .animation(.easeInOut(duration: 0.2), value: deviceManager.activeDevice?.isConnected)
    }

    // MARK: – Stroke Range

    @ViewBuilder
    private var strokeRangeSection: some View {
        if deviceManager.activeDevice?.type == .handy {
            VStack(spacing: 16) {
                HStack {
                    Label("Hub-Bereich", systemImage: "arrow.left.and.right")
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
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 24)
        }
    }


}
