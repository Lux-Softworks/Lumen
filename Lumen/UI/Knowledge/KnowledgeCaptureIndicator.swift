import SwiftUI

struct KnowledgeCaptureIndicator: View {
    @State private var isVisible: Bool = false
    @State private var hideTask: Task<Void, Never>?

    private let label = "Knowledge initiated"
    private let visibleDurationMs: UInt64 = 1400

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.95))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.55))
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.92, anchor: .topTrailing)
        .blur(radius: isVisible ? 0 : 4)
        .animation(.smooth(duration: 0.28), value: isVisible)
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: .knowledgeCaptured)) { _ in
            showPill()
        }
    }

    private func showPill() {
        hideTask?.cancel()
        isVisible = true

        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: visibleDurationMs * 1_000_000)
            guard !Task.isCancelled else { return }
            isVisible = false
        }
    }
}
