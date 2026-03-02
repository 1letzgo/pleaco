//
//  ThemeManager.swift
//  pleaco
//

import SwiftUI

extension Color {
    static var appAccent: Color { Color("AppTint") }
    
    // Deep purple derived from app accent for a unified branded look
    static let cardBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.10, blue: 0.18, alpha: 1) // Deep branded purple
            : UIColor.white
    })
    
    static let surfacePrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.05, blue: 0.07, alpha: 1)   // deep warm dark
            : UIColor(red: 0.985, green: 0.972, blue: 0.978, alpha: 1) // warm off-white
    })
    
    static let surfaceSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.08, blue: 0.10, alpha: 1)
            : UIColor(red: 0.968, green: 0.948, blue: 0.958, alpha: 1)
    })
    
    static let surfaceTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.06, blue: 0.08, alpha: 1)
            : UIColor(red: 0.948, green: 0.925, blue: 0.938, alpha: 1)
    })
    
    static let subtleBorder = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.20, blue: 0.25, alpha: 1)   // warm mauve border
            : UIColor(red: 0.82, green: 0.72, blue: 0.78, alpha: 0.5)
    })
    
    // Softer bloom glow (less aggressive than before)
    static let glowAccent = Color("AppTint").opacity(0.28)
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    
    // Unified branded background for the footer player
    static let footerBackground = Color(red: 0.16, green: 0.10, blue: 0.18)
}

extension LinearGradient {
    // Primary rose gradient for active states & main buttons
    static let accentGradient = LinearGradient(
        colors: [Color.appAccent, Color(hue: 0.88, saturation: 0.50, brightness: 0.68)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Soft card shimmer overlay (inner highlight)
    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.07), .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Warm rose gradient for sliders & waveforms
    static let roseGradient = LinearGradient(
        colors: [Color.appAccent, Color.appAccent.opacity(0.60)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Subtle shimmer for progress bars
    static let bloomGradient = LinearGradient(
        colors: [
            Color.appAccent.opacity(0.95),
            Color(hue: 0.88, saturation: 0.42, brightness: 0.72).opacity(0.75)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Silky-smooth, organic press feel
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct GlowButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - Branded Component Styles

struct ProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient.accentGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.glowAccent, radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.subtleBorder, lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
