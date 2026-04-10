import SwiftUI

struct KnowledgeAIView: View {
    @Bindable var viewModel: KnowledgeAIViewModel

    var body: some View {
        VStack {
            Spacer()
            Text("AI Search")
                .font(AppTheme.Typography.sansBody(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.text.opacity(0.4))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
