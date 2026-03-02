//
//  HomeView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject var loveSpouseManager = LoveSpouseManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 1. Manual Touch Control
                if deviceManager.activeDevice?.type == .ossm {
                    OSSMControlView()
                } else {
                    TouchControlView()
                }

                // 2. Device Programs
                patternsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }

    


    // MARK: – Patterns

    private var patternsSection: some View {
        Group {
            // 1. Hardware Programs (LoveSpouse only)
            if deviceManager.activeDevice?.type == .lovespouse {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Device Programs", icon: "cpu")
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...9, id: \.self) { index in
                            let title = index <= 9 ? patternName(index) : "Pattern \(index - 3)"
                            let icon = patternIcon(index)
                            
                            PatternCard(
                                title: title,
                                curvePoints: [],
                                systemIcon: icon,
                                isSelected: deviceManager.selectedLoveSpouseProgram == index
                            ) {
                                deviceManager.selectLoveSpouseProgram(index)
                            }
                        }
                    }
                }
            }
            
            // 2. Internal / App Patterns (Global)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "App Patterns", icon: "square.grid.3x3.fill")
                
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(DeviceWavePreset.allCases) { preset in
                        PatternCard(
                            title: preset.displayName,
                            curvePoints: [],
                            systemIcon: preset.icon,
                            isSelected: deviceManager.selectedPreset == preset
                        ) {
                            deviceManager.applyPreset(preset)
                        }
                    }
                }
            }
        }
    }

    private func patternName(_ prog: Int) -> String {
        switch prog {
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        case 4: return "Rabbit"
        case 5: return "Ping-Pong"
        case 6: return "Smartphone"
        case 7: return "Gearbox"
        case 8: return "Acceleration"
        case 9: return "Emergency"
        default: return "Pattern \(prog - 3)"
        }
    }

    private func patternIcon(_ prog: Int) -> String {
        switch prog {
        case 1...3: return "speedometer"
        case 4: return "hare.fill"           // Rabbit
        case 5: return "figure.table.tennis" // Ping-Pong
        case 6: return "iphone"              // Smartphone
        case 7: return "gearshape.2.fill"     // Gearbox
        case 8: return "gauge.with.dots.needle.bottom.100percent" // Acceleration
        case 9: return "exclamationmark.triangle.fill" // Emergency
        default:
            let icons = ["waveform", "waveform.path.ecg", "waveform.path.ecg.rectangle",
                         "chart.bar.fill", "chart.line.uptrend.xyaxis", "bolt.fill"]
            return icons[(prog - 1) % icons.count]
        }
    }
}

// MARK: – Live Control Card (Keep if still needed elsewhere, or move if restricted)

struct LiveControlCard: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.22) : Color.surfaceSecondary)
                        .frame(width: 64, height: 64)
                        .shadow(color: isSelected ? Color.glowAccent : .clear, radius: 12)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.appAccent)
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .appCardStyle(isSelected: isSelected)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
    }
}
