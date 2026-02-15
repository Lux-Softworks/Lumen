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
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isBottomBarExpanded = false
                        isAddressBarFocused = false
                    }
                }
            )
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea()
    }
}

#Preview {
    BrowserView()
}
