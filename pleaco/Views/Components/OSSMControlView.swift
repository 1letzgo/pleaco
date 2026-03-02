import SwiftUI

struct OSSMControlView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Master Speed (Manual Intensity)
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Speed", icon: "speedometer")
                
                PLEASlider(
                    value: $deviceManager.masterIntensity,
                    range: 0...100,
                    label: "\(Int(deviceManager.masterIntensity))%",
                    onChanged: {
                        deviceManager.applyManualControl()
                        deviceManager.sendLevel(deviceManager.masterIntensity)
                    }
                )
            }
            
            // Stroke Length
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Stroke length", icon: "arrow.up.and.down.and.sparkles")
                
                PLEASlider(
                    value: $deviceManager.ossmStroke,
                    range: 0...100,
                    label: "\(Int(deviceManager.ossmStroke))%"
                )
            }
            
            // Depth (only show if not in Stroker Mode, or functionally linked)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Depth", icon: "arrow.down.to.line.compact")
                    Spacer()
                    if deviceManager.ossmStrokerMode {
                        Text("Auto-linked")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appAccent.opacity(0.2))
                            .foregroundColor(Color.appAccent)
                            .cornerRadius(8)
                    }
                }
                
                PLEASlider(
                    value: $deviceManager.ossmDepth,
                    range: 0...100,
                    label: "\(Int(deviceManager.ossmDepth))%"
                )
                .opacity(deviceManager.ossmStrokerMode ? 0.6 : 1.0)
                .disabled(deviceManager.ossmStrokerMode)
            }
            
            // Sensation
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sensation", icon: "sparkles")
                
                PLEASlider(
                    value: $deviceManager.ossmSensation,
                    range: 0...100,
                    label: "\(Int(deviceManager.ossmSensation))%"
                )
            }
            
            // Stroker Mode Toggle
            HStack {
                Label("Stroker Mode", systemImage: "link")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Toggle("", isOn: $deviceManager.ossmStrokerMode)
                    .labelsHidden()
                    .tint(Color.appAccent)
            }
            .padding(16)
            .appCardStyle()
        }
    }
}

// MARK: - Generic Reusable Slider Components
struct PLEASlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    var onChanged: (() -> Void)? = nil
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
            
            // Fill
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.appAccent.opacity(0.3), Color.appAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width))
            }
            
            // Label
            HStack {
                Spacer()
                Text(label)
                    .font(.system(size: 18, weight: .black).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
            }
            
            // Gesture Layer
            Slider(value: $value, in: range, onEditingChanged: { _ in
                onChanged?()
            })
            .opacity(0.01) // Transparent native slider for handling hit testing easily
        }
        .frame(height: 64)
    }
}
