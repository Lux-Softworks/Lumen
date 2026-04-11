import SwiftUI
import UIKit

public enum AppTheme {
    public enum Colors {
        public static let background = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 20/255, green: 20/255, blue: 20/255, alpha: 1)       // #141414
                    : UIColor(red: 242/255, green: 240/255, blue: 235/255, alpha: 1)     // #F2F0EB
            })

        public static let uiElement = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1)        // #1E1E1E
                    : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)     // #FFFFFF
            })

        public static let accent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 1)      // #FF9F0A
                    : UIColor(red: 230/255, green: 135/255, blue: 0/255, alpha: 1)        // #E68700
            })

        public static let secondaryAccent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 214/255, blue: 10/255, alpha: 1)       // #FFD60A
                    : UIColor(red: 218/255, green: 178/255, blue: 0/255, alpha: 1)        // #DAB200
            })

        public static let text = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 232/255, green: 228/255, blue: 220/255, alpha: 1)     // #E8E4DC
                    : UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1)        // #1E1E1E
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
