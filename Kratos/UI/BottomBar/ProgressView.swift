import SwiftUI

struct ProgressView: View {
    var progress: Double
    var isLoading: Bool
    var width: CGFloat
    var cornerRadius: CGFloat

    @State private var displayedProgress: Double = 0
    @State private var visible: Bool = false
    @State private var isFinishing: Bool = false

    private let gradient = LinearGradient(
        colors: [
            AppTheme.Colors.accent.opacity(0.5),
            AppTheme.Colors.accent.opacity(0.8),
            AppTheme.Colors.accent,
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(gradient)
                .blur(radius: 12)
                .opacity(0.25)
                .frame(height: 5.5)
                .shadow(
                    color: AppTheme.Colors.accent.opacity(0.25),
                    radius: 1, y: 10
                )

            Capsule()
                .fill(gradient)
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 1, y: 1
                )
                .frame(height: 1.3)
        }
        .scaleEffect(x: displayedProgress, anchor: .leading)
        .frame(maxWidth: width - cornerRadius * 2, maxHeight: .infinity, alignment: .topLeading)
        .opacity(visible ? 1 : 0)
        .offset(y: -2.2)
        .onChange(of: isLoading) { _, loading in
            if loading {
                isFinishing = false

                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    displayedProgress = 0
                }

                withAnimation(.smooth(duration: 0.3)) {
                    visible = true
                }
            } else {
                isFinishing = true
                withAnimation(.smooth(duration: 0.3)) {
                    displayedProgress = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard self.isFinishing else { return }

                    withAnimation(.smooth(duration: 0.3)) {
                        visible = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        }
        .onChange(of: progress) { _, newValue in
            guard !isFinishing else { return }

            if newValue > displayedProgress {
                withAnimation(.spring(response: 0.5, dampingFraction: 1.0)) {
                    displayedProgress = newValue
                }
            }
        }
    }
}
