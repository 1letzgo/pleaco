//
//  LoveSpouseControlView.swift
//  pleaco
//
//  Lets the user directly select one of the 9 built-in LoveSpouse programs
//  (1–3 speed levels, 4–9 vibration patterns) or stop the toy.
//

import SwiftUI

struct LoveSpouseControlView: View {
    @ObservedObject private var manager = LoveSpouseManager.shared
    @ObservedObject private var deviceManager = DeviceManager.shared

    var body: some View {
        VStack(spacing: 0) {
            stopBanner

            ScrollView {
                VStack(spacing: 24) {
                    speedSection
                    patternSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.surfacePrimary)
        .navigationTitle("LoveSpouse")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: – Stop banner

    private var stopBanner: some View {
        Button {
            manager.stopAll()
            deviceManager.stop()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("Stop")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                manager.activeProgram == 0
                    ? Color.gray.opacity(0.4)
                    : Color.red.opacity(0.75)
            )
        }
        .animation(.easeInOut(duration: 0.2), value: manager.activeProgram == 0)
    }

    // MARK: – Speed section (programs 1–3)

    private var speedSection: some View {
        GroupBox {
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { prog in
                    ProgramButton(
                        program: prog,
                        label: speedLabel(prog),
                        icon: "speedometer",
                        isActive: manager.activeProgram == prog
                    ) {
                        manager.selectProgram(prog)
                        if !deviceManager.isPlaying { deviceManager.start() }
                    }
                }
            }
        } label: {
            SectionHeader(title: "Geschwindigkeit", icon: "hare.fill")
                .textCase(nil)
        }
        .groupBoxStyle(PlainGroupBoxStyle())
    }

    // MARK: – Pattern section (programs 4–9)

    private var patternSection: some View {
        GroupBox {
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(4...9, id: \.self) { prog in
                    ProgramButton(
                        program: prog,
                        label: "Muster \(prog - 3)",
                        icon: patternIcon(prog),
                        isActive: manager.activeProgram == prog
                    ) {
                        manager.selectProgram(prog)
                        if !deviceManager.isPlaying { deviceManager.start() }
                    }
                }
            }
        } label: {
            SectionHeader(title: "Muster", icon: "waveform.path")
                .textCase(nil)
        }
        .groupBoxStyle(PlainGroupBoxStyle())
    }

    // MARK: – Helpers

    private func speedLabel(_ prog: Int) -> String {
        switch prog {
        case 1: return "Leicht"
        case 2: return "Mittel"
        case 3: return "Stark"
        default: return "–"
        }
    }

    private func patternIcon(_ prog: Int) -> String {
        let icons = ["waveform", "waveform.path.ecg", "waveform.path.ecg.rectangle",
                     "chart.bar.fill", "chart.line.uptrend.xyaxis", "bolt.fill"]
        return icons[(prog - 4) % icons.count]
    }
}

// MARK: – Program Button

private struct ProgramButton: View {
    let program: Int
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isActive ? .white : .primary)

                Text("\(program)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isActive ? .white.opacity(0.7) : .secondary)

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .fill(isActive
                          ? LinearGradient.accentGradient
                          : LinearGradient(colors: [Color.cardBackground], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                            .strokeBorder(isActive ? Color.clear : Color.subtleBorder, lineWidth: 0.5)
                    )
            )
            .shadow(color: isActive ? Color.glowAccent.opacity(0.4) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: – Plain GroupBox Style

private struct PlainGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
            configuration.content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    NavigationStack { LoveSpouseControlView() }
}
