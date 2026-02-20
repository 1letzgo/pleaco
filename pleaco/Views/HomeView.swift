//
//  HomeView.swift
//  pleaco
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - HomeView

struct HomeView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Section {
                        VStack(alignment: .leading, spacing: 24) {
                            Spacer().frame(height: 60) // High padding to safely cover notch/status bar area
                            // 2. Live Control Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Live Control")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.appMagenta.opacity(0.8))
                                    .padding(.horizontal, 4)
                                
                                HStack(spacing: 12) {
                                    LiveControlCard(title: "Mikrofon", icon: "mic.fill", isSelected: deviceManager.isAudioReactive) {
                                        deviceManager.applyPreset(.audioReactive)
                                        if !deviceManager.isPlaying { deviceManager.start() }
                                    }
                                    LiveControlCard(title: "Touchpad", icon: "hand.tap.fill", isSelected: deviceManager.isManual) {
                                        deviceManager.applyPreset(.manual)
                                        if !deviceManager.isPlaying { deviceManager.start() }
                                    }
                                }
                                
                                // Interaction Area for Live Controls
                                if deviceManager.isManual {
                                    TouchpadArea()
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                } else if deviceManager.isAudioReactive {
                                    MicrophoneVisualizer()
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 20)
                            .animation(.spring(), value: deviceManager.selectedPreset)
                            
                            // 3. Patterns Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Patterns")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.appMagenta.opacity(0.8))
                                    Spacer()
                                    FunScriptImportButton()
                                }
                                .padding(.horizontal, 4)
                                VStack(alignment: .leading, spacing: 20) {
                                     ForEach(PatternGroup.allCases.filter { $0 != .reactive }, id: \.rawValue) { group in
                                         // Skip custom group if empty
                                         if group != .custom || !deviceManager.customScripts.isEmpty {
                                             VStack(alignment: .leading, spacing: 8) {
                                                 Text(group.rawValue)
                                                     .font(.system(size: 14, weight: .bold))
                                                     .foregroundColor(Color.appMagenta.opacity(0.5))
                                                     .padding(.horizontal, 4)
                                                 
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
                                                                 .frame(width: 110)
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
                                                             .frame(width: 110)
                                                         }
                                                     }
                                                     .padding(.horizontal, 4)
                                                 }
                                             }
                                         }
                                     }
                                 }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 24)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Subcomponents

struct TouchpadArea: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var location: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appCardBackground)
                    .shadow(color: Color.appCardShadow, radius: 8, y: 4)
                
                VStack {
                    Text("Draw or Tap to Control")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appMagenta.opacity(0.3))
                    
                    Image(systemName: "hand.draw")
                        .font(.system(size: 32))
                        .foregroundColor(Color.appMagenta.opacity(0.1))
                }
                
                // Visual Indicator
                if location != .zero {
                    Circle()
                        .fill(Color.appMagenta.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .position(location)
                        .transition(.scale)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        location = value.location
                        // Simple 1D control based on vertical position (0 at top, 1 at bottom)
                        // Or 2D? Usually Touchpad implies 1D intensity for these toys
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
    }
}

struct MicrophoneVisualizer: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<15) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < Int(deviceManager.audioLevel / 6.6) ? Color.appMagenta : Color.appMagenta.opacity(0.1))
                        .frame(width: 12, height: i < Int(deviceManager.audioLevel / 6.6) ? CGFloat.random(in: 10...30) : 10)
                }
            }
            .frame(height: 40)
            
            Text("Listening for audio...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBackground)
                .shadow(color: Color.appCardShadow, radius: 8, y: 4)
        )
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
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : Color.appMagenta.opacity(0.4))
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color.appMagenta.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appMagenta : Color.appCardBackground)
                    .shadow(color: Color.appCardShadow, radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .clear : Color.appMagenta.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomPatternGridCard: View {
    let script: NamedFunScript
    let isSelected: Bool
    let onTap: () -> Void
    
    private var curvePoints: [Double] {
        PatternEngine.sampleFunScriptCurve(script.data, pointCount: 80)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Waveform line
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width
                    let h = size.height
                    let count = curvePoints.count
                    
                    let yInset: CGFloat = 2
                    let drawH = h - (yInset * 2)
                    
                    var path = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = yInset + (drawH - CGFloat(val) * drawH)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(isSelected ? .white : Color.appMagenta.opacity(0.4)), lineWidth: 1.5)
                }
                .frame(height: 34)
                .padding(.top, 12)
                
                Text(script.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color.appMagenta.opacity(0.8))
                    .lineLimit(1)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appMagenta : Color.appCardBackground)
                    .shadow(color: isSelected ? Color.appMagenta.opacity(0.2) : Color.appCardShadow, radius: 8, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16)) // Ensure canvas doesn't bleed outside corners
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                DeviceManager.shared.removeCustomScript(script)
            } label: {
                Label("Script löschen", systemImage: "trash")
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
            VStack(spacing: 0) {
                // Waveform line
                Canvas { context, size in
                    guard curvePoints.count > 1 else { return }
                    let w = size.width
                    let h = size.height
                    let count = curvePoints.count
                    
                    let yInset: CGFloat = 2
                    let drawH = h - (yInset * 2)
                    
                    var path = Path()
                    for (i, val) in curvePoints.enumerated() {
                        let x = CGFloat(i) / CGFloat(count - 1) * w
                        let y = yInset + (drawH - CGFloat(val) * drawH)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(isSelected ? .white : Color.appMagenta.opacity(0.4)), lineWidth: 1.5)
                }
                .frame(height: 34)
                .padding(.top, 12)
                
                Text(preset.shortName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color.appMagenta.opacity(0.8))
                    .padding(.top, 10)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.appMagenta : Color.appCardBackground)
                    .shadow(color: isSelected ? Color.appMagenta.opacity(0.2) : Color.appCardShadow, radius: 8, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Views

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
                .font(.system(size: 22))
                .foregroundColor(Color.appMagenta)
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
                
                // De-duplication check
                if deviceManager.customScripts.contains(where: { $0.name == fileName }) {
                    alertMessage = "Ein Script mit dem Namen \"\(fileName)\" existiert bereits."
                    showingAlert = true
                    return
                }

                do {
                    let data = try Data(contentsOf: url)
                    let script = try JSONDecoder().decode(FunScriptData.self, from: data)
                    let namedScript = NamedFunScript(name: fileName, data: script)
                    deviceManager.addCustomScript(namedScript)
                    deviceManager.applyNamedFunScript(namedScript)
                    
                    alertMessage = "\"\(fileName)\" wurde erfolgreich importiert."
                    showingAlert = true
                } catch {
                    alertMessage = "Fehler beim Import: \(error.localizedDescription)"
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

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
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
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
                
                // Highlighted Range
                Capsule()
                    .fill(Color.white)
                    .frame(width: CGFloat((upperValue - lowerValue) / (range.upperBound - range.lowerBound)) * geometry.size.width, height: 4)
                    .offset(x: CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width)
                
                // Lower Thumb
                ThumbView()
                    .offset(x: CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = Double(value.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                lowerValue = min(max(range.lowerBound, newValue), upperValue - 5)
                                onEditingChanged(true)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
                
                // Upper Thumb
                ThumbView()
                    .offset(x: CGFloat((upperValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = Double(value.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                                upperValue = max(min(range.upperBound, newValue), lowerValue + 5)
                                onEditingChanged(true)
                            }
                            .onEnded { _ in
                                onEditingChanged(false)
                            }
                    )
            }
            .frame(height: 20)
        }
    }
}

struct ThumbView: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .shadow(color: .black.opacity(0.2), radius: 2)
            .overlay(
                Circle()
                    .stroke(Color.appMagenta.opacity(0.2), lineWidth: 1)
            )
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
