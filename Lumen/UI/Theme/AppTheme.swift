import SwiftUI
import UIKit

public enum AppTheme {
    public enum Colors {
        public static let background = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 20/255, green: 20/255, blue: 20/255, alpha: 1) // night
                    : UIColor(red: 242/255, green: 240/255, blue: 235/255, alpha: 1) // linen
            })

        public static let uiElement = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1) // charcoal
                    : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1) // white
            })

        public static let accent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 1) // orange
                    : UIColor(red: 230/255, green: 135/255, blue: 0/255, alpha: 1) // ochre
            })

        public static let secondaryAccent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 214/255, blue: 10/255, alpha: 1) // yellow
                    : UIColor(red: 218/255, green: 178/255, blue: 0/255, alpha: 1) // gold
            })

        public static let text = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 232/255, green: 228/255, blue: 220/255, alpha: 1) // cloud
                    : UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1)// charcoal
            })
    }

    public enum Typography {
        public static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }

        public static func sansBody(size: CGFloat, weight: Font.Weight = .medium) -> Font {
            return .system(size: size, weight: weight, design: .default)
        }
    }

    public enum Motion {
        public static let standard: Animation = .spring(duration: 0.42, bounce: 0.18)
        public static let snappy: Animation = .spring(duration: 0.28, bounce: 0.12)
        public static let micro: Animation = .spring(duration: 0.18, bounce: 0)
        public static let sheet: Animation = .spring(duration: 0.46, bounce: 0.14)
        public static let fade: Animation = .easeOut(duration: 0.18)
    }
}
