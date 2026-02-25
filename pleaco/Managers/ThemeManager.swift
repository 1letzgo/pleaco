//
//  ThemeManager.swift
//  pleaco
//

import SwiftUI

extension Color {
    static var appAccent: Color { Color("AppTint") }
    
    static let cardBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.14, alpha: 1)
            : UIColor.white
    })
    
    static let surfacePrimary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.08, alpha: 1)
            : UIColor.systemGroupedBackground
    })
    
    static let surfaceSecondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    })
    
    static let surfaceTertiary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.06, alpha: 1)
            : UIColor.tertiarySystemGroupedBackground
    })
    
    static let subtleBorder = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : UIColor.separator
    })
    
    static let glowAccent = Color("AppTint").opacity(0.35)
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

extension LinearGradient {
    static let accentGradient = LinearGradient(
        colors: [Color.appAccent, Color.appAccent.opacity(0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.04), .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GlowButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
