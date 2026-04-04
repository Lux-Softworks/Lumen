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
                Text("Knowledge")
                    .font(AppTheme.Typography.serifDisplay(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.text)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    KnowledgePanelView()
}
