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
        VStack(spacing: 0) {
            PlayerCard()

            ScrollView {
                VStack(spacing: 28) {
                    patternsSection
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 12)
                .padding(.bottom, 20)
            }
        }
        .background(Color.surfacePrimary)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
    }

    // MARK: – Patterns

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            // 1. Hardware Programs (LoveSpouse only)
            if deviceManager.activeDevice?.type == .lovespouse {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Geräte-Programme", icon: "cpu")
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...9, id: \.self) { index in
                            let isSpeed = index <= 3
                            let title = isSpeed ? speedLabel(index) : "Muster \(index - 3)"
                            let icon = isSpeed ? "speedometer" : patternIcon(index)
                            
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
                    .padding(.horizontal)
                }
            }

            // 2. App Patterns (Software Presets)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "App-Muster", icon: "waveform")
                    .padding(.horizontal)

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
                            if !deviceManager.isPlaying { deviceManager.start() }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // 3. Scripts (Custom FunScripts)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Skripte", icon: "scroll")
                    Spacer()
                    FunScriptImportButton()
                }
                .padding(.horizontal)

                if deviceManager.customScripts.isEmpty {
                    Text("Keine Skripte importiert")
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
                                if !deviceManager.isPlaying { deviceManager.start() }
                            } onDelete: {
                                deviceManager.removeCustomScript(script)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

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
        if prog <= 3 { return "speedometer" }
        return icons[(prog - 4) % icons.count]
    }
}

// MARK: – Player Card (sticky)

struct PlayerCard: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // ── Top row: waveform · info · transport ──────────────────────
            HStack(spacing: 14) {
                // Waveform thumbnail
                MiniWaveformPreview()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )

                // Pattern name + device
                VStack(alignment: .leading, spacing: 4) {
                    Text(deviceManager.currentPatternName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(deviceManager.activeDevice?.isConnected == true
                                  ? Color.appAccent.opacity(0.85) : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(deviceManager.activeDevice?.name ?? "Kein Gerät")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Transport controls
                HStack(spacing: 18) {
                    Button { deviceManager.selectPreviousPattern() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if deviceManager.isPlaying { deviceManager.stop() }
                        else { deviceManager.start() }
                    } label: {
                        ZStack {
                            // Bloom pulse ring while playing
                            Circle()
                                .fill(Color.appAccent.opacity(0.18))
                                .frame(width: 52, height: 52)
                                .scaleEffect(deviceManager.isPlaying ? 1.0 : 0.75)
                                .animation(
                                    deviceManager.isPlaying
                                        ? .easeInOut(duration: 1.3).repeatForever(autoreverses: true)
                                        : .easeOut(duration: 0.25),
                                    value: deviceManager.isPlaying
                                )

                            Circle()
                                .fill(LinearGradient.accentGradient)
                                .frame(width: 42, height: 42)
                                .shadow(color: Color.glowAccent, radius: 10, x: 0, y: 5)

                            Image(systemName: deviceManager.isPlaying ? "pause.fill" : "play.fill")
                                .contentTransition(.symbolEffect(.replace))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .opacity(deviceManager.activeDevice?.isConnected == true ? 1 : 0.4)

                    Button { deviceManager.selectNextPattern() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if deviceManager.activeDevice?.type != .lovespouse {
                // ── Intensity slider ─────────────────────────────────────────
                VStack(spacing: 6) {
                    HStack {
                        Text("Intensität")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(deviceManager.currentLevel))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $deviceManager.currentLevel, in: 0...100) { editing in
                        if !editing { deviceManager.setLevel(deviceManager.currentLevel) }
                    }
                    .tint(Color.appAccent)
                }
            }

            if deviceManager.activeDevice?.type == .handy {
                // ── Stroke Range slider ──────────────────────────────────────
                VStack(spacing: 6) {
                    HStack {
                        Text("Hub-Bereich")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(deviceManager.strokeMin))–\(Int(deviceManager.strokeMax))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    RangeSlider(
                        lowerValue: $deviceManager.strokeMin,
                        upperValue: $deviceManager.strokeMax,
                        range: 0...100
                    ) { editing in
                        if !editing {
                            deviceManager.setStrokeRange(
                                min: deviceManager.strokeMin,
                                max: deviceManager.strokeMax
                            )
                        }
                    }
                    .frame(height: 28)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(
            Color.cardBackground
                .overlay(
                    // Subtle rose bloom when playing
                    LinearGradient(
                        colors: [Color.appAccent.opacity(deviceManager.isPlaying ? 0.07 : 0), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .bottom) {
            Divider()
        }
        .animation(.easeInOut(duration: 0.4), value: deviceManager.isPlaying)
    }
}

// MARK: – Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.semibold))
            .foregroundColor(Color.appAccent.opacity(0.9))
    }
}

// MARK: – Playing Indicator (pulsing petals)

struct PlayingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.5)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: isAnimating ? 18 : 6)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever()
                            .delay(Double(i) * 0.14),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 22)
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}


// MARK: – Live Control Card

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
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.15) : Color.subtleBorder,
                        lineWidth: 0.5
                    )
            )
            .overlay(
                // Shimmer highlight at top-left when selected
                LinearGradient.cardGradient
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .opacity(isSelected ? 1 : 0)
            )
            .shadow(
                color: isSelected ? Color.glowAccent : .black.opacity(0.07),
                radius: isSelected ? 20 : 5,
                x: 0,
                y: isSelected ? 10 : 3
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.95))
    }
}


// MARK: – Pattern Card

struct PatternCard: View {
    let title: String
    let curvePoints: [Double]
    var systemIcon: String? = nil
    let isSelected: Bool
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    if let icon = systemIcon, curvePoints.count <= 1 {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(isSelected ? .white : Color.appAccent)
                    } else {
                        Canvas { context, size in
                            guard curvePoints.count > 1 else { return }
                            let w = size.width
                            let h = size.height
                            let count = curvePoints.count
                            let yInset: CGFloat = 6
                            let drawH = h - yInset * 2

                            var path = Path()
                            for (i, val) in curvePoints.enumerated() {
                                let x = CGFloat(i) / CGFloat(count - 1) * w
                                let y = yInset + (drawH - CGFloat(val) * drawH)
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                            context.stroke(
                                path,
                                with: .color(isSelected ? .white : Color.appAccent),
                                lineWidth: 2.2
                            )
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 8)
                    }
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                LinearGradient.cardGradient
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .opacity(isSelected ? 1 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.12) : Color.subtleBorder,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.glowAccent : .black.opacity(0.05),
                radius: isSelected ? 14 : 3,
                x: 0,
                y: isSelected ? 7 : 2
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: – FunScript Import Button

struct FunScriptImportButton: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingPicker = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Importieren")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(Color.appAccent)
        }
        #if os(iOS)
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in
                let fileName = url.deletingPathExtension().lastPathComponent

                guard url.startAccessingSecurityScopedResource() else {
                    alertMessage = "Zugriff auf Datei verweigert."
                    showingAlert = true
                    return
                }

                defer { url.stopAccessingSecurityScopedResource() }

                if deviceManager.customScripts.contains(where: { $0.name == fileName }) {
                    alertMessage = "Ein Skript mit dem Namen \"\(fileName)\" existiert bereits."
                    showingAlert = true
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    let script = try JSONDecoder().decode(FunScriptData.self, from: data)
                    let namedScript = NamedFunScript(name: fileName, data: script)
                    deviceManager.addCustomScript(namedScript)
                    deviceManager.applyNamedFunScript(namedScript)
                } catch {
                    alertMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
        #endif
        .alert("Import-Fehler", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: – Range Slider

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.surfaceTertiary)
                    .frame(height: 6)

                Capsule()
                    .fill(LinearGradient.roseGradient)
                    .frame(
                        width: CGFloat((upperValue - lowerValue) / (range.upperBound - range.lowerBound))
                            * geometry.size.width,
                        height: 6
                    )
                    .offset(
                        x: CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound))
                            * geometry.size.width
                    )

                thumbView(value: lowerValue, isLower: true)
                thumbView(value: upperValue, isLower: false)
            }
            .frame(height: 28)
        }
    }

    @ViewBuilder
    private func thumbView(value: Double, isLower: Bool) -> some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                .overlay(
                    Circle()
                        .strokeBorder(Color.appAccent.opacity(0.4), lineWidth: 2)
                )
                .offset(
                    x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                        * geometry.size.width - 13
                )
                .gesture(
                    DragGesture()
                        .onChanged { dragValue in
                            let clampedX = max(0, min(dragValue.location.x, geometry.size.width))
                            let newValue = Double(clampedX / geometry.size.width)
                                * (range.upperBound - range.lowerBound) + range.lowerBound

                            if isLower {
                                lowerValue = min(max(range.lowerBound, newValue), upperValue - 5)
                            } else {
                                upperValue = max(min(range.upperBound, newValue), lowerValue + 5)
                            }
                            onEditingChanged(true)
                        }
                        .onEnded { _ in onEditingChanged(false) }
                )
        }
    }
}

// MARK: – Document Picker

#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types: [UTType] = [.json]
        if let funscriptType = UTType(filenameExtension: "funscript") {
            types.insert(funscriptType, at: 0)
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}
#endif
