import SwiftUI
import UIKit

@MainActor
struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()

    @State private var bottomBarState: BottomBarState = .collapsed
    @State private var isReady = false

    @FocusState private var isAddressBarFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 162 / 255, green: 179 / 255, blue: 219 / 255),
                            Color(red: 252 / 255, green: 238 / 255, blue: 209 / 255),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )

                    Group {
                        Circle()
                            .fill(Color(red: 162 / 255, green: 179 / 255, blue: 219 / 255))
                            .frame(width: geometry.size.width * 0.8)
                            .blur(radius: 40)
                            .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.1)
                            .opacity(0.8)

                        Circle()
                            .fill(Color(red: 154 / 255, green: 196 / 255, blue: 237 / 255))
                            .frame(width: geometry.size.width * 0.9)
                            .blur(radius: 50)
                            .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.4)
                            .opacity(0.8)

                        Circle()
                            .fill(Color(red: 185 / 255, green: 219 / 255, blue: 222 / 255))
                            .frame(width: geometry.size.width * 0.6)
                            .blur(radius: 45)
                            .offset(x: -geometry.size.width * 0.1, y: geometry.size.height * 0.7)
                            .opacity(0.5)
                    }
                    .opacity(0.8)

                    Color.black.opacity(0.3)

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .opacity(0.7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .ignoresSafeArea()
                .zIndex(0)

                HardenedWebView(
                    viewModel: viewModel,
                    bottomInset: (bottomBarState == .search || bottomBarState == .browserSettings
                        || bottomBarState == .siteSettings)
                        ? 0 : (bottomBarState == .hidden ? 20 : 80)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                .blur(radius: isReady ? 0 : 20)
                .zIndex(1)

                BottomBarView(
                    text: $viewModel.urlString,
                    state: $bottomBarState,
                    isFocused: $isAddressBarFocused,
                    isLoading: viewModel.isLoading,
                    progress: viewModel.estimatedProgress,
                    searchSuggestions: viewModel.searchSuggestions,
                    themeColor: viewModel.themeColor,
                    currentURL: viewModel.currentURL,
                    onTabsPressed: { print("Tabs pressed") },
                    onSettingsPressed: {
                        if bottomBarState == .collapsed {
                            withAnimation(.smooth(duration: 0.3)) {
                                if let url = viewModel.currentURL, !url.absoluteString.isEmpty,
                                    url.absoluteString != "about:blank"
                                {
                                    bottomBarState = .siteSettings
                                } else {
                                    bottomBarState = .browserSettings
                                }
                            }
                        }
                    },
                    onSubmit: {
                        Task { await viewModel.processUserInput(viewModel.urlString) }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            bottomBarState = .collapsed
                            isAddressBarFocused = false
                        }
                    },
                    onHistoryTap: { url in
                        viewModel.urlString = url
                        Task { await viewModel.processUserInput(url) }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            bottomBarState = .collapsed
                            isAddressBarFocused = false
                        }
                    },
                    onCopyUrl: {
                        if let validURL = viewModel.currentURL?.absoluteString, !validURL.isEmpty,
                            validURL != "about:blank"
                        {
                            UIPasteboard.general.string = validURL
                        } else {
                            UIPasteboard.general.string = viewModel.urlString
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            bottomBarState = .collapsed
                        }
                    }
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                .onChange(of: viewModel.scrollDelta) { _, delta in
                    updateScrollState(delta: delta)
                }
                .blur(radius: isReady ? 0 : 20)
                .zIndex(999)

                if !isReady {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 162 / 255, green: 179 / 255, blue: 219 / 255),
                                Color(red: 252 / 255, green: 238 / 255, blue: 209 / 255),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Color.black.opacity(0.3)
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .opacity(0.7)
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
                    withAnimation(.smooth(duration: 0.3)) {
                        bottomBarState = .search
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

            if scrollAccumulator > 50 && bottomBarState == .collapsed {
                withAnimation(.smooth(duration: 0.3)) {
                    bottomBarState = .hidden
                }
            }
        } else {
            if scrollAccumulator > 0 { scrollAccumulator = 0 }
            scrollAccumulator += delta

            if scrollAccumulator < -20 && bottomBarState == .hidden {
                withAnimation(.smooth(duration: 0.3)) {
                    bottomBarState = .collapsed
                }
            }
        }
    }
}

#Preview {
    BrowserView()
}
