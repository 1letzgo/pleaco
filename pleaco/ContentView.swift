//
//  ContentView.swift
//  pleaco
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = .init(0)

    var body: some View {
        VStack(spacing: 0) {
            // Custom Top Navigation Bar
            CustomTopBar(selectedTab: $selectedTab)
                .padding(.top, 8) // Optional safe area padding, depends on iOS version
                .zIndex(1)

            // Main Content Area
            ZStack {
                switch selectedTab {
                case 0:
                    HomeView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case 1:
                    AudioView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case 2:
                    SettingsView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .background(Color.surfacePrimary.ignoresSafeArea())
        .tint(Color.appAccent)
    }
}

// MARK: – Mini Waveform Preview (still used in PlayerCard)

struct MiniWaveformPreview: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    private var curvePoints: [Double] {
        if let script = deviceManager.activeFunScript {
            return PatternEngine.sampleFunScriptCurve(script, pointCount: 30)
        }
        return PatternEngine.cachedCurves[deviceManager.selectedPreset] ?? []
    }

    var body: some View {
        ZStack {
            Color.surfaceSecondary

            if !curvePoints.isEmpty {
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width, h = size.height
                    let count = curvePoints.count
                    let inset: CGFloat = 6
                    let dh = h - inset * 2

                    var line = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = inset + dh - CGFloat(val) * dh
                        if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                        else { line.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(line, with: .color(Color.appAccent), lineWidth: 2.2)
                }
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.appAccent.opacity(0.7))
            }
        }
    }
}
