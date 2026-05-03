import SwiftUI
import UIKit

struct FaviconView: View {
    let url: URL?
    var size: CGFloat = 16
    var cornerRadius: CGFloat = 4
    var isIncognito: Bool = false

    @State private var image: UIImage?
    @Environment(\.palette) private var palette

    init(url: URL?, size: CGFloat = 16, cornerRadius: CGFloat = 4, isIncognito: Bool = false) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
        self.isIncognito = isIncognito
        if let url, let cached = FaviconService.cachedFavicon(for: url) {
            self._image = State(initialValue: cached)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(palette.text.opacity(0.18))
                .opacity(image == nil ? 1 : 0)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .task(id: url?.absoluteString ?? "") { await load() }
    }

    private func load() async {
        guard let url else {
            setImage(nil)
            return
        }
        if let cached = FaviconService.cachedFavicon(for: url) {
            setImage(cached)
            return
        }
        if isIncognito {
            setImage(nil)
            return
        }
        let result = await FaviconService.fetchFavicon(for: url)
        setImage(result)
    }

    @MainActor
    private func setImage(_ value: UIImage?) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { self.image = value }
    }
}

struct TabHeaderLabel: View {
    let title: String
    let url: URL?
    var isIncognito: Bool = false
    var textOpacity: CGFloat = 1
    var iconSize: CGFloat = 16
    var contrastBackground: UIColor? = nil

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            FaviconView(url: url, size: iconSize, isIncognito: isIncognito)

            HStack(spacing: 0) {
                if isIncognito {
                    Text("Incognito · ")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                }
                Text(visibleTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .opacity(textOpacity)

            Spacer(minLength: 0)
        }
    }

    private var visibleTitle: String {
        title.isEmpty ? "New Tab" : title
    }

    private var textColor: Color {
        if isIncognito { return IncognitoPalette.accent }
        if let bg = contrastBackground { return ContrastForeground.color(for: bg) }
        return palette.text
    }
}

enum ContrastForeground {
    static func color(for ui: UIColor?) -> Color {
        guard let ui else { return Color.primary }
        return isLight(ui) ? darkColor : Color.white
    }

    static func uiColor(for ui: UIColor?) -> UIColor {
        guard let ui else { return .label }
        return isLight(ui) ? darkUIColor : .white
    }

    private static let darkUIColor = UIColor(white: 0.18, alpha: 1.0)
    private static let darkColor = Color(white: 0.18)

    private static func isLight(_ ui: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        let luminance = 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        return luminance > 0.55
    }

    private static func channel(_ v: CGFloat) -> CGFloat {
        let s = max(0, min(1, v))
        return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
    }
}
