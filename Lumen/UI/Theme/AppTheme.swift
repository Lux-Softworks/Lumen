import SwiftUI
import UIKit

public enum AppTheme {
    public enum Colors {
        public static let background = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 15 / 255, green: 15 / 255, blue: 15 / 255, alpha: 1)  // #0F0F0F
                    : UIColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 1)  // #FFFFFF
            })

        public static let uiElement = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)  // #1C1C1E
                    : UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)  // #F2F2F7
            })

        public static let accent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 255 / 255, green: 107 / 255, blue: 53 / 255, alpha: 1)  // #FF6B35
                    : UIColor(red: 211 / 255, green: 84 / 255, blue: 0 / 255, alpha: 1)  // #D35400
            })

        public static let secondaryAccent = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 174 / 255, green: 182 / 255, blue: 191 / 255, alpha: 1)  // #AEB6BF
                    : UIColor(red: 93 / 255, green: 109 / 255, blue: 126 / 255, alpha: 1)  // #5D6D7E
            })

        public static let text = Color(
            UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 248 / 255, green: 249 / 255, blue: 250 / 255, alpha: 1)  // #F8F9FA
                    : UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)  // #1C1C1E
            })
    }
}
