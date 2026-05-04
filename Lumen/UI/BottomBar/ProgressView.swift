import SwiftUI

struct ProgressView: View {
    var progress: Double
    var isLoading: Bool
    var width: CGFloat
    var cornerRadius: CGFloat

    @State private var displayedProgress: Double = 0
    @State private var visible: Bool = false
    @State private var isFinishing: Bool = false
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [
                palette.accent.opacity(0.7),
                palette.accent.opacity(0.85),
                palette.accent,
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var glowGradient: LinearGradient {
        LinearGradient(
            colors: [
                palette.accent.opacity(0.35),
                palette.accent.opacity(0.8),
                palette.accent.opacity(0.45),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var tipGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.52),
                .init(color: palette.accent.opacity(0.45), location: 0.80),
                .init(color: palette.accent.opacity(0.85), location: 1.0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Ellipse()
                .fill(glowGradient)
                .blur(radius: 28)
                .opacity(0.11)
                .frame(height: 38)

            Ellipse()
                .fill(glowGradient)
                .blur(radius: 9)
                .opacity(0.26)
                .frame(height: 14)

            Capsule()
                .fill(barGradient)
                .blur(radius: 2)
                .opacity(0.5)
                .frame(height: 4)

            Ellipse()
                .fill(tipGradient)
                .blur(radius: 5)
                .opacity(0.78)
                .frame(height: 10)

            Capsule()
                .fill(barGradient)
                .frame(height: 1)
        }
        .scaleEffect(x: displayedProgress, anchor: .leading)
        .frame(maxWidth: width - cornerRadius * 2, maxHeight: .infinity, alignment: .topLeading)
        .opacity(visible ? 1 : 0)
        .offset(y: -18.95)
        .onChange(of: isLoading) { _, loading in
            if loading {
                isFinishing = false

                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    displayedProgress = 0
                }

                withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                    visible = true
                }
            } else {
                isFinishing = true
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                    displayedProgress = 1.0
                }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard self.isFinishing else { return }

                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                        visible = false
                    }

                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard self.isFinishing else { return }

                    var transaction = Transaction(animation: .none)
                    transaction.disablesAnimations = true

                    withTransaction(transaction) {
                        displayedProgress = 0
                    }
                    isFinishing = false
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            guard !isFinishing else { return }

            if newValue > displayedProgress {
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 1.0)) {
                    displayedProgress = newValue
                }
            }
        }
    }
}
