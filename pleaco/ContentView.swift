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
        .tint(Color.appAccent)
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
    }
}

struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        HStack(spacing: 14) {
            MiniWaveformPreview()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(deviceManager.currentPatternName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(deviceManager.activeDevice?.isConnected == true ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    
                    Text(deviceManager.activeDevice?.name ?? "No Device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    deviceManager.selectPreviousPattern()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    if deviceManager.isPlaying { deviceManager.stop() }
                    else { deviceManager.start() }
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
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.glowAccent, radius: 8, x: 0, y: 4)
                        
                        Image(systemName: deviceManager.isPlaying ? "pause.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .opacity(deviceManager.activeDevice?.isConnected == true ? 1 : 0.4)

                Button {
                    deviceManager.selectNextPattern()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { showPlayer = true }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            GeometryReader { geometry in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.appAccent.opacity(deviceManager.isPlaying ? 0.9 : 0.3),
                                Color.appAccent.opacity(deviceManager.isPlaying ? 0.6 : 0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(4, geometry.size.width * CGFloat(deviceManager.currentLevel / 100.0)),
                        height: 3,
                        alignment: .leading
                    )
                    .animation(.linear(duration: 0.1), value: deviceManager.currentLevel)
                    .animation(.easeInOut(duration: 0.35), value: deviceManager.isPlaying)
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
                    context.stroke(line, with: .color(Color.appAccent), lineWidth: 2)
                }
            } else if deviceManager.isAudioReactive {
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { i in
                        let norm = Double(i) / 6.0
                        let envelope = sin(norm * .pi)
                        let barH = max(4.0, 4.0 + (deviceManager.audioLevel / 100.0) * envelope * 20.0)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.6)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: CGFloat(barH))
                            .animation(.easeOut(duration: 0.08), value: deviceManager.audioLevel)
                    }
                }
            } else {
                Image(systemName: deviceManager.isManual ? "hand.tap.fill" : "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.appAccent.opacity(0.7))
            }
        }
    }
}
