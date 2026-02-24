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
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.devices)
        }
        .tint(Color.accentColor)
        .sheet(isPresented: $showPlayer) {
            PlayerView()
        }
    }
}

struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        Button { showPlayer = true } label: {
            HStack(spacing: 14) {
                MiniWaveformPreview()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(deviceManager.currentPatternName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(deviceManager.activeDevice?.name ?? "No Device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if deviceManager.isPlaying { deviceManager.stop() }
                    else { deviceManager.start() }
                } label: {
                    Image(systemName: deviceManager.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(deviceManager.activeDevice?.isConnected == true ? 1 : 0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            GeometryReader { geo in
                Color.accentColor
                    .opacity(deviceManager.isPlaying ? 0.8 : 0.3)
                    .frame(width: geo.size.width * CGFloat(deviceManager.currentLevel / 100.0), height: 3)
            }
            .frame(height: 3)
        }
    }
}

struct MiniWaveformPreview: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    private var curvePoints: [Double] {
        if deviceManager.isAudioReactive || deviceManager.isManual { return [] }
        if let script = deviceManager.activeFunScript {
            return PatternEngine.sampleFunScriptCurve(script, pointCount: 30)
        }
        return PatternEngine.cachedCurves[deviceManager.selectedPreset] ?? []
    }

    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)

            if !curvePoints.isEmpty {
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width, h = size.height
                    let count = curvePoints.count
                    let inset: CGFloat = 4
                    let dh = h - inset * 2

                    var line = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = inset + dh - CGFloat(val) * dh
                        if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                        else { line.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(line, with: .color(Color.accentColor), lineWidth: 1.5)
                }
            } else if deviceManager.isAudioReactive {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor)
            } else {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.accentColor)
            }
        }
    }
}
