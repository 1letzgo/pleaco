//
//  HomeView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var deviceManager = DeviceManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                
                liveControlSection
                
                patternsSection
                
                Spacer(minLength: 20)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 60)
        }
        .scrollClipDisabled()
        .background(Color.surfacePrimary)
        .navigationTitle("Control")
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Control Center")
                    .font(.title.bold())
            }
            Spacer()
            
            if deviceManager.isPlaying {
                PlayingIndicator()
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var liveControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Live Control", icon: "hand.tap.fill")

            HStack(spacing: 12) {
                LiveControlCard(
                    title: "Microphone",
                    icon: "mic.fill",
                    subtitle: "Audio Reactive",
                    isSelected: deviceManager.isAudioReactive
                ) {
                    deviceManager.applyPreset(.audioReactive)
                    if !deviceManager.isPlaying { deviceManager.start() }
                }

                LiveControlCard(
                    title: "Touchpad",
                    icon: "hand.draw.fill",
                    subtitle: "Manual Control",
                    isSelected: deviceManager.isManual
                ) {
                    deviceManager.applyPreset(.manual)
                    if !deviceManager.isPlaying { deviceManager.start() }
                }
            }
            .padding(.horizontal)

            if deviceManager.isManual {
                TouchpadArea()
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            } else if deviceManager.isAudioReactive {
                MicrophoneVisualizer()
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deviceManager.isManual)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deviceManager.isAudioReactive)
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Patterns", icon: "waveform")
                Spacer()
                FunScriptImportButton()
            }
            .padding(.horizontal)

            ForEach(PatternGroup.allCases.filter { $0 != .reactive }, id: \.rawValue) { group in
                if group != .custom || !deviceManager.customScripts.isEmpty {
                    PatternGroupView(group: group)
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundColor(.secondary)
    }
}

struct PlayingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

struct PatternGroupView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    let group: PatternGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if group == .custom {
                        ForEach(deviceManager.customScripts) { script in
                            PatternCard(
                                title: script.name,
                                curvePoints: PatternEngine.sampleFunScriptCurve(
                                    script.data,
                                    pointCount: 60
                                ),
                                isSelected: deviceManager.activeFunScriptId == script.id
                            ) {
                                deviceManager.applyNamedFunScript(script)
                                if !deviceManager.isPlaying { deviceManager.start() }
                            } onDelete: {
                                DeviceManager.shared.removeCustomScript(script)
                            }
                            .frame(width: 130)
                        }
                    }

                    ForEach(group.presets, id: \.self) { preset in
                        PatternCard(
                            title: preset.shortName,
                            curvePoints: PatternEngine.cachedCurves[preset] ?? [],
                            isSelected: deviceManager.selectedPreset == preset
                                && deviceManager.activeFunScript == nil
                                && !deviceManager.isAudioReactive
                                && !deviceManager.isManual
                        ) {
                            deviceManager.applyPreset(preset)
                            if !deviceManager.isPlaying { deviceManager.start() }
                        }
                        .frame(width: 130)
                    }
                }
                .padding(.horizontal)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

struct LiveControlCard: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.cardBackground)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                }

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.subtleBorder,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.glowAccent : .black.opacity(0.08),
                radius: isSelected ? 16 : 4,
                x: 0,
                y: isSelected ? 8 : 2
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96))
    }
}

struct TouchpadArea: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var location: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                    )

                if location == .zero {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "hand.draw")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundColor(Color.appAccent.opacity(0.6))
                        }
                        Text("Touch to Control")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if location != .zero {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appAccent.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .position(location)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.glowAccent, radius: 8)
                        .position(location)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.2)) {
                            location = value.location
                        }
                        let intensity = 1.0 - Double(value.location.y / geometry.size.height)
                        deviceManager.manualIntensity = max(0, min(1, intensity))
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            location = .zero
                        }
                        deviceManager.manualIntensity = 0
                    }
            )
        }
        .frame(height: 180)
        .padding(.horizontal)
    }
}

struct MicrophoneVisualizer: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    private let barCount = 20

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(0..<barCount, id: \.self) { i in
                    let fraction = deviceManager.audioLevel / 100.0
                    let norm = Double(i) / Double(barCount - 1)
                    let envelope = sin(norm * .pi)
                    let barH = max(6.0, 6.0 + fraction * envelope * 36.0)
                    let isLit = Double(i) / Double(barCount) < fraction * 1.2

                    Capsule()
                        .fill(
                            isLit
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(0.6)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ))
                                : AnyShapeStyle(Color.cardBackground)
                        )
                        .frame(width: 10, height: CGFloat(barH))
                        .animation(.easeOut(duration: 0.06), value: deviceManager.audioLevel)
                }
            }
            .frame(height: 48)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 6, height: 6)
                    .opacity(deviceManager.audioLevel > 5 ? 1 : 0.3)
                
                Text("Listening...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal)
    }
}

struct PatternCard: View {
    let title: String
    let curvePoints: [Double]
    let isSelected: Bool
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.surfaceTertiary)
                        .frame(height: 56)
                    
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
                            lineWidth: 2
                        )
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 8)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.subtleBorder,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.glowAccent : .black.opacity(0.06),
                radius: isSelected ? 12 : 3,
                x: 0,
                y: isSelected ? 6 : 2
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

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
                Text("Import")
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
                    alertMessage = "Access to file denied."
                    showingAlert = true
                    return
                }

                defer { url.stopAccessingSecurityScopedResource() }

                if deviceManager.customScripts.contains(where: { $0.name == fileName }) {
                    alertMessage = "A script named \"\(fileName)\" already exists."
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
                    alertMessage = "Import failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
        #endif
        .alert("Import Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

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
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent, Color.appAccent.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                .overlay(
                    Circle()
                        .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 2)
                )
                .offset(
                    x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                        * geometry.size.width - 12
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
