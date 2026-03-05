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
            VStack(spacing: 20) {
                artworkSection

                infoSection

                if deviceManager.activeDevice?.type != .lovespouse && deviceManager.activeDevice?.type != .ossm {
                    intensitySection
                }

                deviceStatusSection

                strokeRangeSection

                transportControls
                    .padding(.top, 16) // A little extra breathing room before controls

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
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )

            // Soft bloom vignette when playing
            if deviceManager.isPlaying {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
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
        .padding(.top, 60)
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
                SectionHeader(title: "Intensity", icon: "slider.horizontal.3")
                Spacer()
                Text("\(Int(deviceManager.currentLevel))%")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.appAccent.opacity(0.8))
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
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
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
            VStack(spacing: 20) {
                HStack {
                    SectionHeader(title: "Stroke Range", icon: "arrow.up.and.down")
                    Spacer()
                    Text("\(Int(deviceManager.strokeMin))% - \(Int(deviceManager.strokeMax))%")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.appAccent.opacity(0.8))
                        .monospacedDigit()
                }

                RangeSlider(lowerValue: $deviceManager.strokeMin, upperValue: $deviceManager.strokeMax, range: 0...100) { editing in
                    if !editing {
                        deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax)
                    }
                }
                .frame(height: 32)
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
        } else if deviceManager.activeDevice?.type == .ossm {
            VStack(spacing: 28) {
                // STROKER MODE Toggle
                HStack {
                    SectionHeader(title: "Stroker Mode", icon: "arrow.left.and.right.circle.fill")
                    Spacer()
                    Toggle("", isOn: $deviceManager.ossmStrokerMode)
                        .labelsHidden()
                        .tint(Color.appAccent)
                }
                .padding(.bottom, 4)

                // SPEED (Intensity)
                OSSMControlSlider(
                    title: "SPEED",
                    value: $deviceManager.currentLevel,
                    limitMin: $deviceManager.ossmSpeedLimitMin,
                    limitMax: $deviceManager.ossmSpeedLimitMax,
                    icon: "gauge.with.needle",
                    onSubmit: { deviceManager.setLevel(deviceManager.currentLevel) }
                )

                // STROKE
                OSSMControlSlider(
                    title: "STROKE",
                    value: $deviceManager.strokeMax,
                    limitMin: $deviceManager.ossmStrokeLimitMin,
                    limitMax: $deviceManager.ossmStrokeLimitMax,
                    icon: "arrow.left.and.right",
                    onSubmit: { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                )

                // DEPTH
                OSSMControlSlider(
                    title: "DEPTH",
                    value: $deviceManager.strokeMin,
                    limitMin: $deviceManager.ossmDepthLimitMin,
                    limitMax: $deviceManager.ossmDepthLimitMax,
                    icon: "arrow.down.and.line.horizontal.and.arrow.up",
                    onSubmit: { deviceManager.setStrokeRange(min: deviceManager.strokeMin, max: deviceManager.strokeMax) }
                )
                
                // SENSATION
                OSSMControlSlider(
                    title: "SENSATION",
                    value: $deviceManager.ossmSensation,
                    limitMin: $deviceManager.ossmSensationLimitMin,
                    limitMax: $deviceManager.ossmSensationLimitMax,
                    icon: "antenna.radiowaves.left.and.right",
                    onSubmit: { }
                )

                // PATTERN DESCRIPTION
                if let patternIdx = Int(exactly: deviceManager.ossmManager.availablePatterns.firstIndex(of: deviceManager.currentPatternName) ?? -1),
                   let desc = deviceManager.ossmManager.patternDescriptions[patternIdx], !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Description", icon: "text.alignleft")
                            .padding(.bottom, 2)
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
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
    }

}

// MARK: – OSSM Control Components

struct OSSMControlSlider: View {
    let title: String
    @Binding var value: Double
    @Binding var limitMin: Double
    @Binding var limitMax: Double
    var range: ClosedRange<Double> = 0...100
    let icon: String
    var onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                SectionHeader(title: title, icon: icon)
                Spacer()
                Text("\(Int(value))%")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.appAccent.opacity(0.8))
                    .monospacedDigit()
            }

            // Main constrained slider
            Slider(value: $value, in: limitMin...limitMax, step: 1) { editing in
                if !editing { onSubmit() }
            }
            .tint(Color.appAccent)

            // Range limits underneath
            VStack(spacing: 8) {
                HStack {
                    Text("LIMITS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                    Text("\(Int(limitMin))% - \(Int(limitMax))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                        .monospacedDigit()
                }

                RangeSlider(lowerValue: $limitMin, upperValue: $limitMax, range: range)
                    .frame(height: 20)
                    .opacity(0.6)
                    .onChange(of: limitMin) { oldValue, newValue in
                        // Rescale value proportionally to new range
                        let oldRange = limitMax - oldValue
                        let newRange = limitMax - newValue
                        if oldRange > 0 {
                            let proportion = (value - oldValue) / oldRange
                            value = max(newValue, min(limitMax, newValue + (proportion * newRange)))
                        } else {
                            value = max(newValue, min(limitMax, value))
                        }
                        onSubmit()
                    }
                    .onChange(of: limitMax) { oldValue, newValue in
                        // Rescale value proportionally to new range
                        let oldRange = oldValue - limitMin
                        let newRange = newValue - limitMin
                        if oldRange > 0 {
                            let proportion = (value - limitMin) / oldRange
                            value = max(limitMin, min(newValue, limitMin + (proportion * newRange)))
                        } else {
                            value = max(limitMin, min(newValue, value))
                        }
                        onSubmit()
                    }
            } // Close inner VStack
        } // Close outer VStack
    }
}
