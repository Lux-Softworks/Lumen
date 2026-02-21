import SwiftUI
import UIKit

@MainActor
struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()

    @State private var isBottomBarExpanded = false
    @State private var isBottomBarCollapsed = false
    @State private var isReady = false

    @FocusState private var isAddressBarFocused: Bool

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
                            .frame(width: geometry.size.width * 0.8)
                            .blur(radius: 80)
                            .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.1)
                            .opacity(0.8)

                        Circle()
                            .fill(Color.yellow)
                            .frame(width: geometry.size.width * 0.9)
                            .blur(radius: 100)
                            .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.4)
                            .opacity(0.8)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * 0.6)
                            .blur(radius: 90)
                            .offset(x: -geometry.size.width * 0.1, y: geometry.size.height * 0.7)
                            .opacity(0.5)
                    }
                    .opacity(0.5)

                    Rectangle()
                        .fill(.ultraThinMaterial).opacity(0.96)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .ignoresSafeArea()
                .zIndex(0)

                HardenedWebView(
                    viewModel: viewModel,
                    bottomInset: isBottomBarExpanded ? 0 : (isBottomBarCollapsed ? 20 : 80)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                .zIndex(1)

                BottomBarView(
                    text: $viewModel.urlString,
                    isExpanded: $isBottomBarExpanded,
                    isCollapsed: $isBottomBarCollapsed,
                    isFocused: $isAddressBarFocused,
                    isLoading: viewModel.isLoading,
                    progress: viewModel.estimatedProgress,
                    searchSuggestions: viewModel.searchSuggestions,
                    onTabsPressed: { print("Tabs pressed") },
                    onSettingsPressed: { print("Settings pressed") },
                    onSubmit: {
                        Task { await viewModel.processUserInput(viewModel.urlString) }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isBottomBarExpanded = false
                            isAddressBarFocused = false
                        }
                    },
                    onHistoryTap: { url in
                        viewModel.urlString = url
                        Task { await viewModel.processUserInput(url) }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isBottomBarExpanded = false
                            isAddressBarFocused = false
                        }
                    }
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .onChange(of: viewModel.scrollDelta) { _, delta in
                    updateScrollState(delta: delta)
                }
                .zIndex(3)

                if !isReady {
                    ZStack {
                        LinearGradient(
                            colors: [.indigo.opacity(0.8), .purple.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Rectangle()
                            .fill(.ultraThinMaterial).opacity(0.96)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.4)) {
                    isReady = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isBottomBarExpanded = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isAddressBarFocused = true
                    }
                }
            }
        }
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
