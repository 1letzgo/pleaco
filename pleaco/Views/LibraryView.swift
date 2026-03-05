//
//  LibraryView.swift
//  pleaco
//

import SwiftUI

struct LibraryView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @ObservedObject var loveSpouseManager = LoveSpouseManager.shared
    @ObservedObject var ossmManager = OSSMManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                deviceControlsSection
                librarySections
                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
    }

    private var deviceControlsSection: some View {
        Group {
            // 1. OSSM Hardware Controls (Removed, user wants to use MediaPlayer card instead)
            
            // 2. LoveSpouse Hardware Programs
            if deviceManager.activeDevice?.type == .lovespouse {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Device Programs", icon: "cpu")
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...9, id: \.self) { index in
                            let title = patternName(index)
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
            
            // 3. OSSM Hardware Programs
            if deviceManager.activeDevice?.type == .ossm && !ossmManager.availablePatterns.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "OSSM Programs", icon: "cpu.fill")
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(ossmManager.availablePatterns.enumerated()), id: \.offset) { index, name in
                            PatternCard(
                                title: name,
                                curvePoints: [],
                                systemIcon: "bolt.fill",
                                isSelected: ossmManager.deviceState == "pattern" && ossmManager.lastRequestedDescriptionIndex == index
                            ) {
                                ossmManager.setPattern(index)
                            }
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
        default: return "Pattern \(prog)"
        }
    }

    private func patternIcon(_ prog: Int) -> String {
        switch prog {
        case 1...3: return "speedometer"
        case 4: return "hare.fill"
        case 5: return "figure.table.tennis"
        case 6: return "iphone"
        case 7: return "gearshape.2.fill"
        case 8: return "gauge.with.dots.needle.bottom.100percent"
        case 9: return "exclamationmark.triangle.fill"
        default: return "waveform"
        }
    }

    private var librarySections: some View {
        VStack(alignment: .leading, spacing: 24) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            // 1. Scripts (Custom FunScripts)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(title: "Scripts", icon: "scroll")
                    Spacer()
                    FunScriptImportButton()
                }

                if deviceManager.customScripts.isEmpty {
                    Text("No scripts imported")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(deviceManager.customScripts) { script in
                            PatternCard(
                                title: script.name,
                                curvePoints: PatternEngine.sampleFunScriptCurve(script.data, pointCount: 60),
                                isSelected: deviceManager.activeFunScriptId == script.id && deviceManager.selectedLoveSpouseProgram == 0
                            ) {
                                deviceManager.applyNamedFunScript(script)
                            } onDelete: {
                                deviceManager.removeCustomScript(script)
                            }
                        }
                    }
                }
            }

            // 2. App Patterns (Software Presets)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "App Patterns", icon: "waveform")

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PatternEngine.navigablePresets, id: \.self) { preset in
                        PatternCard(
                            title: preset.shortName,
                            curvePoints: PatternEngine.cachedCurves[preset] ?? [],
                            isSelected: deviceManager.selectedPreset == preset
                                && deviceManager.activeFunScript == nil
                                && deviceManager.selectedLoveSpouseProgram == 0
                        ) {
                            deviceManager.applyPreset(preset)
                        }
                    }
                }
            }
        }
    }
}
