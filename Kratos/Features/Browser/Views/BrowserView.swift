import SwiftUI
import UIKit

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()

    @State private var isBottomBarExpanded = false
    @State private var isBottomBarCollapsed = false

    @FocusState private var isAddressBarFocused: Bool

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ZStack {
                    LinearGradient(
                        colors: [.indigo.opacity(0.8), .purple.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )

                    Group {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: screenWidth * 0.8)
                            .blur(radius: 80)
                            .offset(x: -screenWidth * 0.2, y: -screenHeight * 0.1)
                            .opacity(0.8)

                        Circle()
                            .fill(Color.yellow)
                            .frame(width: screenWidth * 0.9)
                            .blur(radius: 100)
                            .offset(x: screenWidth * 0.3, y: screenHeight * 0.4)
                            .opacity(0.8)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: screenWidth * 0.6)
                            .blur(radius: 90)
                            .offset(x: -screenWidth * 0.1, y: screenHeight * 0.7)
                            .opacity(0.5)
                    }
                    .opacity(0.5)

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .ignoresSafeArea()
                .zIndex(0)

                HardenedWebView(viewModel: viewModel)
                    .ignoresSafeArea()
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 60)
                    }
                    .zIndex(1)

                Color(uiColor: viewModel.themeColor ?? .systemBackground)
                    .opacity(0.8)
                    .background(.ultraThinMaterial)
                    .frame(height: geometry.safeAreaInsets.top)
                    .ignoresSafeArea()
                    .zIndex(2)

                BottomBarView(
                    text: $viewModel.urlString,
                    isExpanded: $isBottomBarExpanded,
                    isCollapsed: $isBottomBarCollapsed,
                    isFocused: $isAddressBarFocused,
                    isLoading: viewModel.isLoading,
                    progress: viewModel.estimatedProgress,
                    onTabsPressed: { print("Tabs pressed") },
                    onSettingsPressed: { print("Settings pressed") },
                    onSubmit: {
                        Task { await viewModel.processUserInput(viewModel.urlString) }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isBottomBarExpanded = false
                            isAddressBarFocused = false
                        }
                    }
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .onChange(of: viewModel.scrollDelta) { delta in
                    updateScrollState(delta: delta)
                }
                .zIndex(3)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: viewModel.themeColor)
    }

    @State private var scrollAccumulator: CGFloat = 0

    private func updateScrollState(delta: CGFloat) {
        if delta > 0 {
            if scrollAccumulator < 0 { scrollAccumulator = 0 }
            scrollAccumulator += delta

            if scrollAccumulator > 50 && !isBottomBarCollapsed && !isBottomBarExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBottomBarCollapsed = true
                }
            }
        } else {
            if scrollAccumulator > 0 { scrollAccumulator = 0 }
            scrollAccumulator += delta

            if scrollAccumulator < -20 && isBottomBarCollapsed {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBottomBarCollapsed = false
                }
            }
        }
    }
}

#Preview {
    BrowserView()
}
