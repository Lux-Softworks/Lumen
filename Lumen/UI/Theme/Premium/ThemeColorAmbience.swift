// Lumen/UI/Theme/Premium/ThemeColorAmbience.swift
import SwiftUI
import UIKit

struct AmbientPalette: Equatable {
    let tint: Color
    let shadow: Color
    let glow: Color

    static func make(themeColor: Color?, palette: ActivePalette) -> AmbientPalette {
        if palette.isIncognito {
            return AmbientPalette(
                tint: palette.accent,
                shadow: .black,
                glow: palette.accent
            )
        }
        guard let themeColor else {
            return AmbientPalette(
                tint: palette.accent,
                shadow: palette.accent,
                glow: palette.accent
            )
        }
        let ui = UIColor(themeColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return AmbientPalette(tint: themeColor, shadow: themeColor, glow: themeColor)
        }
        let clampedS = min(s, PremiumTokens.ambientSaturationCeiling)
        let clampedB = max(
            min(b, PremiumTokens.ambientBrightnessCeiling),
            PremiumTokens.ambientBrightnessFloor
        )
        let glowS = max(s, PremiumTokens.glowSaturationFloor)

        let shadow = Color(
            hue: Double(h),
            saturation: Double(clampedS),
            brightness: Double(clampedB),
            opacity: 1
        )
        let glow = Color(
            hue: Double(h),
            saturation: Double(glowS),
            brightness: Double(b),
            opacity: 1
        )
        return AmbientPalette(tint: themeColor, shadow: shadow, glow: glow)
    }
}

private struct PageThemeColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private struct AmbientPaletteKey: EnvironmentKey {
    static let defaultValue: AmbientPalette = AmbientPalette.make(themeColor: nil, palette: .standard)
}

extension EnvironmentValues {
    var pageThemeColor: Color? {
        get { self[PageThemeColorKey.self] }
        set { self[PageThemeColorKey.self] = newValue }
    }

    var ambientPalette: AmbientPalette {
        get { self[AmbientPaletteKey.self] }
        set { self[AmbientPaletteKey.self] = newValue }
    }
}
