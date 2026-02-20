//
//  PlayerView.swift
//  pleaco
//

import SwiftUI

struct PlayerView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Artwork / Waveform area
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.appCardBackground)
                    .shadow(radius: 10)
                
                VStack {
                    MiniWaveformPreview()
                        .frame(height: 150)
                        .padding()
                }
            }
            .frame(width: 300, height: 300)
            
            // Info
            VStack(spacing: 8) {
                Text(deviceManager.currentPatternName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(deviceManager.activeDevice?.name ?? "No Device Connected")
                    .font(.headline)
                    .foregroundColor(Color.appMagenta)
            }
            
            // Controls
            HStack(spacing: 40) {
                Button(action: {
                    deviceManager.selectPreviousPattern()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 30))
                }
                .foregroundColor(.primary)
                
                Button(action: {
                    if deviceManager.isPlaying {
                        deviceManager.stop()
                    } else {
                        deviceManager.start()
                    }
                }) {
                    Image(systemName: deviceManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(Color.appMagenta)
                }
                
                Button(action: {
                    deviceManager.selectNextPattern()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 30))
                }
                .foregroundColor(.primary)
            }
            
            // Intensity Slider
            VStack {
                HStack {
                    Image(systemName: "minus")
                    Slider(value: $deviceManager.currentLevel, in: 0...100) { editing in
                        if !editing { deviceManager.setLevel(deviceManager.currentLevel) }
                    }
                    .tint(Color.appMagenta)
                    Image(systemName: "plus")
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)
            
            // Stroke Range (Handy Only)
            if deviceManager.activeDevice?.type == .handy {
                VStack(spacing: 8) {
                    HStack {
                        Text("STROKE RANGE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(deviceManager.strokeMin))% - \(Int(deviceManager.strokeMax))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                    .padding(.top, 4)

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
                    .frame(height: 24)
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
        }
        .background(Color.appBackground)
    }
}
