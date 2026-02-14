import SwiftUI

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @FocusState private var isAddressBarFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                toolbar

                if viewModel.isLoading {
                    ProgressView(value: viewModel.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }

                HardenedWebView(viewModel: viewModel)
                    .ignoresSafeArea(edges: .bottom)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 80)
                    }
            }

            BottomBarView(
                onTabsPressed: {
                    print("Tabs pressed")
                },
                onSettingsPressed: {
                    print("Settings pressed")
                },
                onSearchPressed: {
                    isAddressBarFocused = true
                }
            )
        }
        .onAppear {
            viewModel.loadHomePage()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!viewModel.canGoBack)

                Button(action: viewModel.goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                }
                .disabled(!viewModel.canGoForward)
            }

            HStack(spacing: 6) {
                if viewModel.isSecure {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }

                TextField("Search or enter URL", text: $viewModel.urlString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .focused($isAddressBarFocused)
                    .onSubmit {
                        Task {
                            await viewModel.processUserInput(viewModel.urlString)
                        }
                        isAddressBarFocused = false
                    }

                if viewModel.isLoading {
                    Button(action: viewModel.stopLoading) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            HStack(spacing: 8) {
                Button(action: viewModel.reload) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                }

                privacyBadge
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
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
