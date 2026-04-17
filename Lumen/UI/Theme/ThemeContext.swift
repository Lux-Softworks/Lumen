import SwiftUI

struct ActivePalette {
    let background: Color
    let uiElement: Color
    let accent: Color
    let text: Color
    let secondaryAccent: Color
    let isIncognito: Bool

    static let standard = ActivePalette(
        background: AppTheme.Colors.background,
        uiElement: AppTheme.Colors.uiElement,
        accent: AppTheme.Colors.accent,
        text: AppTheme.Colors.text,
        secondaryAccent: AppTheme.Colors.secondaryAccent,
        isIncognito: false
    )

    static let incognito = ActivePalette(
        background: IncognitoPalette.background,
        uiElement: IncognitoPalette.uiElement,
        accent: IncognitoPalette.accent,
        text: IncognitoPalette.text,
        secondaryAccent: IncognitoPalette.secondaryAccent,
        isIncognito: true
    )
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: ActivePalette = .standard
}

extension EnvironmentValues {
    var palette: ActivePalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
