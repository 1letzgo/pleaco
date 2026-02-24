//
//  HomeView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live Controls Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Live Control", systemImage: "hand.tap.fill")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            LiveControlCard(title: "Microphone", icon: "mic.fill", isSelected: deviceManager.isAudioReactive) {
                                deviceManager.applyPreset(.audioReactive)
                                if !deviceManager.isPlaying { deviceManager.start() }
                            }
                            
                            LiveControlCard(title: "Touchpad", icon: "hand.draw.fill", isSelected: deviceManager.isManual) {
                                deviceManager.applyPreset(.manual)
                                if !deviceManager.isPlaying { deviceManager.start() }
                            }
                        }
                        .padding(.horizontal)
                        
                        if deviceManager.isManual {
                            TouchpadArea()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else if deviceManager.isAudioReactive {
                            MicrophoneVisualizer()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    
                    // Patterns Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Patterns", systemImage: "waveform")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            FunScriptImportButton()
                        }
                        .padding(.horizontal)
                        
                        ForEach(PatternGroup.allCases.filter { $0 != .reactive }, id: \.rawValue) { group in
                            if group != .custom || !deviceManager.customScripts.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            if group == .custom {
                                                ForEach(deviceManager.customScripts) { script in
                                                    CustomPatternGridCard(
                                                        script: script,
                                                        isSelected: deviceManager.activeFunScriptId == script.id
                                                    ) {
                                                        deviceManager.applyNamedFunScript(script)
                                                        if !deviceManager.isPlaying { deviceManager.start() }
                                                    }
                                                    .frame(width: 120)
                                                }
                                            }
                                            
                                            ForEach(group.presets, id: \.self) { preset in
                                                PatternGridCard(
                                                    preset: preset,
                                                    isSelected: deviceManager.selectedPreset == preset && deviceManager.activeFunScript == nil
                                                ) {
                                                    deviceManager.applyPreset(preset)
                                                    if !deviceManager.isPlaying { deviceManager.start() }
                                                }
                                                .frame(width: 120)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.vertical)
            }
            .background(Color.appBackground)
        }
    }
}

struct LiveControlCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.appContrast.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct TouchpadArea: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var location: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appContrast.opacity(0.05))
                
                VStack {
                    Text("Touch to Control")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "hand.draw")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                if location != .zero {
                    Circle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 50, height: 50)
                        .position(location)
                        .transition(.scale)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        location = value.location
                        let intensity = Double(1.0 - (value.location.y / geometry.size.height))
                        deviceManager.manualIntensity = max(0, min(1, intensity))
                    }
                    .onEnded { _ in
                        withAnimation {
                            location = .zero
                            deviceManager.manualIntensity = 0
                        }
                    }
            )
        }
        .frame(height: 160)
        .padding(.horizontal)
    }
}

struct MicrophoneVisualizer: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<15) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < Int(deviceManager.audioLevel / 6.6) ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: i < Int(deviceManager.audioLevel / 6.6) ? CGFloat.random(in: 10...30) : 10)
                        .animation(.easeInOut(duration: 0.1), value: deviceManager.audioLevel)
                }
            }
            .frame(height: 40)
            
            Text("Listening for audio...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appContrast.opacity(0.05))
        )
        .padding(.horizontal)
    }
}

struct CustomPatternGridCard: View {
    let script: NamedFunScript
    let isSelected: Bool
    let onTap: () -> Void
    
    private var curvePoints: [Double] {
        PatternEngine.sampleFunScriptCurve(script.data, pointCount: 60)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width
                    let h = size.height
                    let count = curvePoints.count
                    let yInset: CGFloat = 4
                    let drawH = h - (yInset * 2)
                    
                    var path = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = yInset + (drawH - CGFloat(val) * drawH)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(isSelected ? .white : Color.accentColor.opacity(0.6)), lineWidth: 1.5)
                }
                .frame(height: 50)
                
                Text(script.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.appContrast.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                DeviceManager.shared.removeCustomScript(script)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct PatternGridCard: View {
    let preset: DeviceWavePreset
    let isSelected: Bool
    let onTap: () -> Void
    
    private var curvePoints: [Double] {
        PatternEngine.cachedCurves[preset] ?? []
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width
                    let h = size.height
                    let count = curvePoints.count
                    let yInset: CGFloat = 4
                    let drawH = h - (yInset * 2)
                    
                    var path = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = yInset + (drawH - CGFloat(val) * drawH)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(isSelected ? .white : Color.accentColor.opacity(0.6)), lineWidth: 1.5)
                }
                .frame(height: 50)
                
                Text(preset.shortName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color.appContrast.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
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
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(Color.accentColor)
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
                    
                    alertMessage = "\"\(fileName)\" imported successfully."
                    showingAlert = true
                } catch {
                    alertMessage = "Import error: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
        #endif
        .alert("FunScript Import", isPresented: $showingAlert) {
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
                    .fill(Color(uiColor: .systemGray4))
                    .frame(height: 6)
                
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: CGFloat((upperValue - lowerValue) / (range.upperBound - range.lowerBound)) * geometry.size.width, height: 6)
                    .offset(x: CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .offset(x: CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 11)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = Double(value.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                lowerValue = min(max(range.lowerBound, newValue), upperValue - 5)
                                onEditingChanged(true)
                            }
                            .onEnded { _ in onEditingChanged(false) }
                    )
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .offset(x: CGFloat((upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 11)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = Double(value.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                upperValue = max(min(range.upperBound, newValue), lowerValue + 5)
                                onEditingChanged(true)
                            }
                            .onEnded { _ in onEditingChanged(false) }
                    )
            }
            .frame(height: 22)
        }
    }
}

#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(exportedAs: "com.qdot.funscript"), .json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}
#endif
