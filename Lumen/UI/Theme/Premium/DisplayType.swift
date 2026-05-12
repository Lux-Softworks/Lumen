import SwiftUI

extension Font {
    static let displayHero = Font.system(size: 40, weight: .black, design: .default)
    static let displayTitle = Font.system(size: 28, weight: .black, design: .default)
    static let displayHeading = Font.system(size: 22, weight: .bold, design: .default)
    static let displayURL = Font.system(size: 20, weight: .bold, design: .default)
    static let displayLabel = Font.system(size: 13, weight: .semibold, design: .default)
    static let microText = Font.system(size: 13, weight: .medium, design: .default)
}

extension Text {
    func displayHero() -> Text {
        self.font(.displayHero).tracking(-0.8)
    }
    func displayTitle() -> Text {
        self.font(.displayTitle).tracking(-0.5)
    }
    func displayHeading() -> Text {
        self.font(.displayHeading).tracking(-0.3)
    }
    func displayURL() -> Text {
        self.font(.displayURL).tracking(-0.2)
    }
    func displayLabel() -> some View {
        self.font(.displayLabel).tracking(0.6).textCase(.uppercase)
    }
    func microText() -> Text {
        self.font(.microText)
    }
}
