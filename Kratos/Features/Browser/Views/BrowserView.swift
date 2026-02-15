import SwiftUI

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()

    @State private var isBottomBarExpanded = false

    @FocusState private var isAddressBarFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView(value: viewModel.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }

                HardenedWebView(viewModel: viewModel)
                    .ignoresSafeArea(edges: .bottom)
                    .safeAreaInset(edge: .bottom) {
                        // Spacer for the collapsed bottom bar
                        Color.clear.frame(height: 60)
                    }
            }

            BottomBarView(
                text: $viewModel.urlString,
                isExpanded: $isBottomBarExpanded,
                isFocused: $isAddressBarFocused,
                onTabsPressed: {
                    print("Tabs pressed")
                },
                onSettingsPressed: {
                    print("Settings pressed")
                },
                onSubmit: {
                    Task {
                        await viewModel.processUserInput(viewModel.urlString)
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isBottomBarExpanded = false
                        isAddressBarFocused = false
                    }
                }
            )
        }
    }

    private var privacyBadge: some View {
        let count = viewModel.blockedTrackersCount

        return Image(systemName: count > 0 ? "shield.lefthalf.filled" : "shield")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(count > 0 ? .orange : .secondary)
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text("\(min(count, 99))")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(2)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
    }
}

#Preview {
    BrowserView()
}
