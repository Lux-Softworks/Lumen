import SwiftUI

struct KnowledgeCaptureIndicator: View {
    @State private var isVisible: Bool = false
    @State private var hideTask: Task<Void, Never>?
    @State private var label: String = "Knowledge initiated"

    private let visibleDurationMs: UInt64 = 3200

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
        .offset(y: isVisible ? 0 : 10)
        .blur(radius: isVisible ? 0 : 4)
        .animation(.smooth(duration: 0.28), value: isVisible)
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: .knowledgeCaptured)) { note in
            let userInfo = note.userInfo ?? [:]
            if (userInfo["stage"] as? String) == "enrichment" { return }
            let isUpdate = (userInfo["isUpdate"] as? Bool) ?? false
            label = isUpdate ? "Knowledge updated" : "Knowledge initiated"
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
