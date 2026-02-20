//
//  ThemeManager.swift
//  pleaco
//

import SwiftUI
import UIKit

extension Color {
    static let appMagenta = Color(red: 204/255.0, green: 0/255.0, blue: 136/255.0)
    static let appMagentaDark = Color(red: 150/255.0, green: 0/255.0, blue: 100/255.0)
    
    static let appBackground = Color(uiColor: UIColor { traits in
        return traits.userInterfaceStyle == .dark ? UIColor(white: 0.05, alpha: 1.0) : UIColor(white: 0.98, alpha: 1.0)
    })
    
    static let appCardBackground = Color(uiColor: UIColor { traits in
        return traits.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 1.0) : UIColor.white
    })
    
    static let appCardShadow = Color(uiColor: UIColor { traits in
        return traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.3) : UIColor.black.withAlphaComponent(0.05)
    })
    
    static let appSecondaryText = Color(uiColor: UIColor { traits in
        return traits.userInterfaceStyle == .dark ? UIColor(white: 0.7, alpha: 1.0) : UIColor(white: 0.4, alpha: 1.0)
    })
}
