import SwiftUI

struct VibrantBackground: View {
    let size: CGSize
    let isIncognito: Bool

    var body: some View {
        ZStack {
            base
            blobs
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
            sheen
            material
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var base: some View {
        if isIncognito {
            LinearGradient(
                colors: [
                    IncognitoPalette.background,
                    IncognitoPalette.uiElement,
                    IncognitoPalette.background,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.background.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var blobs: some View {
        ZStack {
            ForEach(palette.indices, id: \.self) { index in
                let spec = palette[index]
                Circle()
                    .fill(spec.color.opacity(spec.opacity))
                    .frame(width: size.width * spec.scale)
                    .blur(radius: spec.blur)
                    .offset(x: size.width * spec.x, y: size.height * spec.y)
                    .blendMode(spec.blend)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var sheen: some View {
        LinearGradient(
            colors: [
                .white.opacity(isIncognito ? 0.04 : 0.08),
                .clear,
                .clear,
                .white.opacity(isIncognito ? 0.02 : 0.04),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.plusLighter)
        .opacity(0.7)
    }

    @ViewBuilder
    private var material: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .opacity(isIncognito ? 0.55 : 0.62)
    }

    private var palette: [BlobSpec] {
        isIncognito ? Self.incognitoBlobs : Self.lightBlobs
    }

    private struct BlobSpec {
        let color: Color
        let opacity: Double
        let scale: Double
        let blur: Double
        let x: Double
        let y: Double
        let blend: BlendMode
    }

    private static let lightBlobs: [BlobSpec] = [
        BlobSpec(color: AppTheme.Colors.accent, opacity: 0.55, scale: 1.25,
                 blur: 110, x: -0.25, y: -0.22, blend: .plusLighter),
        BlobSpec(color: AppTheme.Colors.secondaryAccent, opacity: 0.42, scale: 1.15,
                 blur: 100, x: 0.32, y: 0.30, blend: .plusLighter),
        BlobSpec(color: Color(red: 1.0, green: 0.45, blue: 0.55), opacity: 0.30, scale: 0.85,
                 blur: 90, x: 0.30, y: -0.05, blend: .plusLighter),
        BlobSpec(color: Color(red: 0.85, green: 0.30, blue: 0.85), opacity: 0.22, scale: 0.75,
                 blur: 95, x: -0.18, y: 0.12, blend: .plusLighter),
        BlobSpec(color: Color(red: 0.20, green: 0.78, blue: 1.00), opacity: 0.18, scale: 0.70,
                 blur: 85, x: 0.18, y: -0.32, blend: .plusLighter),
        BlobSpec(color: Color(red: 0.55, green: 0.40, blue: 1.00), opacity: 0.20, scale: 0.85,
                 blur: 95, x: -0.30, y: 0.32, blend: .plusLighter),
    ]

    private static let incognitoBlobs: [BlobSpec] = [
        BlobSpec(color: IncognitoPalette.accent, opacity: 0.12, scale: 1.30,
                 blur: 120, x: -0.28, y: -0.25, blend: .plusLighter),
        BlobSpec(color: IncognitoPalette.secondaryAccent, opacity: 0.09, scale: 1.20,
                 blur: 110, x: 0.32, y: 0.30, blend: .plusLighter),
        BlobSpec(color: Color(red: 0.30, green: 0.30, blue: 0.55), opacity: 0.20, scale: 0.95,
                 blur: 110, x: 0.05, y: 0.05, blend: .plusLighter),
        BlobSpec(color: Color(red: 0.40, green: 0.30, blue: 0.55), opacity: 0.16, scale: 0.85,
                 blur: 100, x: -0.30, y: 0.30, blend: .plusLighter),
        BlobSpec(color: Color(red: 0.50, green: 0.62, blue: 0.78), opacity: 0.10, scale: 0.75,
                 blur: 90, x: 0.22, y: -0.30, blend: .plusLighter),
    ]
}
