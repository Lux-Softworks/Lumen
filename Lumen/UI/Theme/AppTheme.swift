import SwiftUI
import UIKit

public enum AppTheme {
    public enum Colors {
        public static let background = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 26/255, green: 25/255, blue: 23/255, alpha: 1)  // #1A1917
                    : UIColor(red: 244/255, green: 243/255, blue: 238/255, alpha: 1) // #F4F3EE
            })

        public static let uiElement = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 35/255, green: 34/255, blue: 32/255, alpha: 1)
                    : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
            })

        public static let accent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 217/255, green: 119/255, blue: 87/255, alpha: 1)  // #D97757
                    : UIColor(red: 193/255, green: 95/255, blue: 60/255, alpha: 1)   // #C15F3C
            })

        public static let secondaryAccent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 140/255, green: 135/255, blue: 125/255, alpha: 1)
                    : UIColor(red: 177/255, green: 173/255, blue: 161/255, alpha: 1)
            })

        public static let text = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 236/255, green: 235/255, blue: 230/255, alpha: 1)
                    : UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1)
            })
    }
    
    public enum Typography {
        public static func serifDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
        
        public static func sansBody(size: CGFloat, weight: Font.Weight = .medium) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
    }
}
