//
//  ContentView.swift
//  pleaco
//

import SwiftUI

struct ContentView: View {
    @State private var activeTab: AppTab = .control
    @State private var showPlayer = false

    enum AppTab {
        case control, devices
    }

    var body: some View {
        TabView(selection: $activeTab) {
            NavigationStack {
                HomeView()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MiniPlayerBar(showPlayer: $showPlayer)
            }
            .tabItem {
                Label("Control", systemImage: "play.circle.fill")
            }
            .tag(AppTab.control)

            SettingsView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MiniPlayerBar(showPlayer: $showPlayer)
                }
                .tabItem {
                    Label("Geräte", systemImage: "wave.3.forward")
                }
                .tag(AppTab.devices)
        }
        .tint(Color.appMagenta)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Mini Player Bar

struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        Button { showPlayer = true } label: {
            HStack(spacing: 14) {
                MiniWaveformPreview()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(deviceManager.currentPatternName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(deviceManager.activeDevice?.name ?? "Kein Gerät")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if deviceManager.isPlaying { deviceManager.stop() }
                    else { deviceManager.start() }
                } label: {
                    Image(systemName: deviceManager.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.appMagenta)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .opacity(deviceManager.activeDevice?.isConnected == true ? 1 : 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                // Separator
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                // Intensity progress line
                GeometryReader { geo in
                    Color.appMagenta
                        .opacity(deviceManager.isPlaying ? 0.6 : 0.25)
                        .frame(width: geo.size.width * CGFloat(deviceManager.currentLevel / 100.0))
                        .animation(.linear(duration: 0.1), value: deviceManager.currentLevel)
                }
                .frame(height: 2)
            }
        }
    }
}

// MARK: - Mini Waveform Preview

struct MiniWaveformPreview: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    private var curvePoints: [Double] {
        if deviceManager.isAudioReactive || deviceManager.isManual { return [] }
        if let script = deviceManager.activeFunScript {
            return PatternEngine.sampleFunScriptCurve(script, pointCount: 40)
        }
        return PatternEngine.cachedCurves[deviceManager.selectedPreset] ?? []
    }

    var body: some View {
        ZStack {
            Color(.systemGray5)

            if !curvePoints.isEmpty {
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width, h = size.height
                    let count = curvePoints.count
                    let inset: CGFloat = 5
                    let dh = h - inset * 2

                    var fill = Path()
                    fill.move(to: CGPoint(x: 0, y: inset + dh))
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = inset + dh - CGFloat(val) * dh
                        fill.addLine(to: CGPoint(x: x, y: y))
                    }
                    fill.addLine(to: CGPoint(x: w, y: inset + dh))
                    fill.closeSubpath()
                    context.fill(fill, with: .color(Color.appMagenta.opacity(0.3)))

                    var line = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = inset + dh - CGFloat(val) * dh
                        if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                        else { line.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(line, with: .color(Color.appMagenta), lineWidth: 1.5)
                }
            } else if deviceManager.isAudioReactive {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.appMagenta.opacity(0.6))
            } else {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.appMagenta.opacity(0.6))
            }
        }
    }
}
