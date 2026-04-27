import SwiftUI
import UIKit

struct KnowledgeButton: View {
    var action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.palette) var palette

    var body: some View {
        Button(action: {
            Haptics.fire(.tap)
            action()
        }) {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .environment(\.colorScheme, palette.isIncognito ? .dark : colorScheme)
                    .overlay(
                        Group {
                            if palette.isIncognito {
                                palette.background.opacity(0.85)
                            } else if colorScheme == .dark {
                                Color.black.opacity(0.28)
                            } else {
                                Color.white.opacity(0.22)
                            }
                        }
                    )
                    .clipShape(FolderTabShape(isFill: true))
            }
            .frame(width: 85, height: 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bottombar.knowledge")
    }
}

struct FolderTabShape: Shape {
    var isFill: Bool = false

    func path(in rect: CGRect) -> Path {
        let totalWidth = rect.width
        let totalHeight = rect.height
        let filletRadius: CGFloat = 12
        let cornerRadius: CGFloat = 10

        var path = Path()

        let baseY = isFill ? totalHeight + 1 : totalHeight

        path.move(to: CGPoint(x: 0, y: baseY))

        path.addQuadCurve(
            to: CGPoint(x: filletRadius, y: totalHeight - filletRadius),
            control: CGPoint(x: filletRadius, y: totalHeight)
        )

        path.addLine(to: CGPoint(x: filletRadius, y: cornerRadius))

        path.addQuadCurve(
            to: CGPoint(x: filletRadius + cornerRadius, y: 0),
            control: CGPoint(x: filletRadius, y: 0)
        )

        path.addLine(to: CGPoint(x: totalWidth - filletRadius - cornerRadius, y: 0))

        path.addQuadCurve(
            to: CGPoint(x: totalWidth - filletRadius, y: cornerRadius),
            control: CGPoint(x: totalWidth - filletRadius, y: 0)
        )

        path.addLine(to: CGPoint(x: totalWidth - filletRadius, y: totalHeight - filletRadius))

        path.addQuadCurve(
            to: CGPoint(x: totalWidth, y: totalHeight),
            control: CGPoint(x: totalWidth - filletRadius, y: totalHeight)
        )

        if isFill {
            path.addLine(to: CGPoint(x: totalWidth, y: baseY))
            path.addLine(to: CGPoint(x: 0, y: baseY))
            path.closeSubpath()
        }

        return path
    }
}
