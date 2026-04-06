import SwiftUI

struct KnowledgePanelView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                AppTheme.Colors.background
                Color.black.opacity(0.3)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .opacity(0.7)
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    KnowledgePanelView()
}
