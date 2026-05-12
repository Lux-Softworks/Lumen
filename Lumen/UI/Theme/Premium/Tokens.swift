import SwiftUI

enum PremiumTokens {
    static let themeColorTween: Animation = .timingCurve(0.25, 1, 0.5, 1, duration: 0.4)

    static let ambientSaturationCeiling: CGFloat = 0.85
    static let ambientBrightnessFloor: CGFloat = 0.15
    static let ambientBrightnessCeiling: CGFloat = 0.85
    static let glowSaturationFloor: CGFloat = 0.5
}
