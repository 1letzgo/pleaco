import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label {
            Text(title.uppercased())
                .tracking(1.2)
        } icon: {
            Image(systemName: icon)
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color.appAccent.opacity(0.8))
    }
}

// MARK: - Standard App Card Style

struct AppCardModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                LinearGradient.cardGradient
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .opacity(isSelected ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.12) : Color.subtleBorder,
                        lineWidth: 0.5
                    )
                    .allowsHitTesting(false)
            )
            .shadow(
                color: isSelected ? Color.glowAccent : .black.opacity(0.05),
                radius: isSelected ? 14 : 3,
                x: 0,
                y: isSelected ? 7 : 2
            )
    }
}

extension View {
    func appCardStyle(isSelected: Bool = false) -> some View {
        self.modifier(AppCardModifier(isSelected: isSelected))
    }
}

// MARK: – Base Card Structure
struct BaseCard<Content: View>: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)

                content()
                    .frame(height: 48)

                Spacer(minLength: 0)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .contentShape(Rectangle())
            .appCardStyle(isSelected: isSelected)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(ScaleButtonStyle())
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
        BaseCard(title: title, isSelected: isSelected, onTap: onTap) {
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
        }
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

// MARK: – FunScript Import Button

import UniformTypeIdentifiers

struct FunScriptImportButton: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var showingPicker = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                Text("Add")
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(Color.appAccent)
        }
        #if os(iOS)
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in
                let fileName = url.deletingPathExtension().lastPathComponent

                guard url.startAccessingSecurityScopedResource() else {
                    alertMessage = "File access denied."
                    showingAlert = true
                    return
                }

                defer { url.stopAccessingSecurityScopedResource() }

                if deviceManager.customScripts.contains(where: { $0.name == fileName }) {
                    alertMessage = "A script with the name \"\(fileName)\" already exists."
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

// MARK: – UI Helpers

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: – Playing Indicator

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
// MARK: – Range Slider

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)

                // Active Range Track
                Capsule()
                    .fill(Color.white)
                    .frame(
                        width: CGFloat((upperValue - lowerValue) / (range.upperBound - range.lowerBound))
                            * (geometry.size.width - 27),
                        height: 6
                    )
                    .offset(
                        x: 13.5 + CGFloat((lowerValue - range.lowerBound) / (range.upperBound - range.lowerBound))
                            * (geometry.size.width - 27)
                    )

                thumbView(value: lowerValue, isLower: true, totalWidth: geometry.size.width)
                thumbView(value: upperValue, isLower: false, totalWidth: geometry.size.width)
            }
            .frame(height: 32)
        }
    }

    @ViewBuilder
    private func thumbView(value: Double, isLower: Bool, totalWidth: CGFloat) -> some View {
        let thumbSize: CGFloat = 27
        let availableWidth = totalWidth - thumbSize
        let xOffset = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * availableWidth

        Circle()
            .fill(Color.white)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            .offset(x: xOffset)
            .gesture(
                DragGesture()
                    .onChanged { dragValue in
                        let clampedX = max(0, min(dragValue.location.x - thumbSize/2, availableWidth))
                        let newValue = Double(clampedX / availableWidth)
                            * (range.upperBound - range.lowerBound) + range.lowerBound

                        if isLower {
                            lowerValue = min(max(range.lowerBound, newValue), upperValue - 2)
                        } else {
                            upperValue = max(min(range.upperBound, newValue), lowerValue + 2)
                        }
                        onEditingChanged(true)
                    }
                    .onEnded { _ in onEditingChanged(false) }
            )
    }
}
