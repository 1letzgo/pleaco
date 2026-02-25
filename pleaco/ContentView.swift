//
//  ContentView.swift
//  pleaco
//

import SwiftUI

struct ContentView: View {
    @State private var activeTab: AppTab = .control

    enum AppTab {
        case control, devices
    }

    var body: some View {
        TabView(selection: $activeTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Control", systemImage: activeTab == .control ? "heart.circle.fill" : "heart.circle")
            }
            .tag(AppTab.control)



            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape.fill")
                }
                .tag(AppTab.devices)
        }
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
