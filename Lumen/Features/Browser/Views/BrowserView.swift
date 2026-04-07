import SwiftUI
import UIKit

@MainActor
struct BrowserView: View {
    @StateObject private var tabManager = TabManager(createDefaultTab: false)
    @State private var bottomBarState: BottomBarState = .collapsed
    @State private var isReady = false
    @State private var activeTabViewState: TabViewState = .fullScreen
    @State private var shrinkProgress: CGFloat = 0
    @State private var scrollAnchor: CGFloat = 0
    @State private var wasScrollingDown: Bool = false
    @State private var urlText: String = ""

    @State private var webViewReady = true
    @State private var coverFinished = false
    @State private var pageCommitted = false

    @State private var showNavigationCover = false
    @State private var navigationCoverProgress: CGFloat = 0
    @State private var navigationCoverOpacity: CGFloat = 1

    @FocusState private var isAddressBarFocused: Bool


    private var isTransitioning: Bool { activeTabViewState.isTransitioning }
    private var activeTab: Tab? { tabManager.activeTab }

    private var pageReadyToken: Int {
        activeTab?.viewModel.pageReadyToken ?? 0
    }

    private var isActiveTabLoading: Bool {
        activeTab?.viewModel.isLoading ?? false
    }

    private var activeTabProgress: Double {
        activeTab?.viewModel.estimatedProgress ?? 0
    }

    private var urlBinding: Binding<String> {
        Binding(
            get: { activeTab?.viewModel.urlString ?? urlText },
            set: { val in
                urlText = val
                activeTab?.viewModel.urlString = val
            }
        )
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        let clampedT = max(0, min(t, 1))
        return a + (b - a) * clampedT
    }

    private func getStatusBarHeight(_ geometry: GeometryProxy) -> CGFloat {
        let top = geometry.safeAreaInsets.top
        return top > 0 ? top : 44
    }

    var body: some View {
        content
            .ignoresSafeArea()
            .applyNavigationCoverChangeHandlers(
                showNavigationCover: $showNavigationCover,
                navigationCoverOpacity: $navigationCoverOpacity,
                navigationCoverProgress: $navigationCoverProgress,
                coverFinished: $coverFinished,
                pageCommitted: $pageCommitted,
                onFadeIn: fadeInWebView
            )
            .applyPageLoadHandlers(
                pageReadyToken: pageReadyToken,
                isActiveTabLoading: isActiveTabLoading,
                activeTabProgress: activeTabProgress,
                webViewReady: $webViewReady,
                coverFinished: coverFinished,
                pageCommitted: $pageCommitted,
                bottomBarState: $bottomBarState,
                onFadeIn: fadeInWebView
            )
            .applyTabManagerHandlers(
                tabManager: tabManager,
                activeTabViewState: $activeTabViewState,
                shrinkProgress: $shrinkProgress,
                webViewReady: $webViewReady,
                bottomBarState: $bottomBarState
            )
            .applyBottomBarFocusHandlers(
                bottomBarState: $bottomBarState,
                isAddressBarFocused: $isAddressBarFocused
            )
            .applyActiveTabChangedHandlers(
                tabManager: tabManager,
                bottomBarState: $bottomBarState,
                isAddressBarFocused: $isAddressBarFocused
            )
            .onAppear {
                withAnimation(.smooth(duration: 0.3).delay(0.3)) {
                    isReady = true
                }
                withAnimation(.smooth(duration: 0.3).delay(0.65)) {
                    bottomBarState = .search
                }
            }
    }

    private var content: some View {
        GeometryReader { geometry in
            mainContent(geometry: geometry)
        }
    }

    @ViewBuilder
    private func mainContent(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            backgroundLayer(geometry: geometry)
                .zIndex(0)
            tabOverlayLayer()
                .zIndex(1)
            activeTabLayer(geometry: geometry)
                .zIndex(1.5)
            transitionLayer(geometry: geometry)
                .zIndex(2)
            bottomBarLayer(geometry: geometry)
                .zIndex(3)
            navigationLayer(geometry: geometry)
                .zIndex(10)
            if !isReady {
                launchScreen.zIndex(200)
            }
        }
    }

    @ViewBuilder
    private func backgroundLayer(geometry: GeometryProxy) -> some View {
        backgroundGradient(geometry: geometry)
    }

    @ViewBuilder
    private func backgroundDecorations(geometry: GeometryProxy) -> some View {
        Group {
            Circle()
                .fill(AppTheme.Colors.accent.opacity(0.4))
                .frame(width: geometry.size.width * 1.2)
                .blur(radius: 100)
                .offset(x: -geometry.size.width * 0.2, y: -geometry.size.height * 0.2)
            Circle()
                .fill(AppTheme.Colors.secondaryAccent.opacity(0.3))
                .frame(width: geometry.size.width * 1.1)
                .blur(radius: 90)
                .offset(x: geometry.size.width * 0.3, y: geometry.size.height * 0.3)
        }
        .opacity(0.8)
    }

    @ViewBuilder
    private func backgroundGradient(geometry: GeometryProxy) -> some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.Colors.background, AppTheme.Colors.background],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            backgroundDecorations(geometry: geometry)
            Color.black.opacity(0.3)
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.7)
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func tabOverlayLayer() -> some View {
        let opacity: Double = {
            switch activeTabViewState {
            case .shrinking:
                return 0
            case .expanding:
                return 0
            case .shrunk:
                return 1
            case .fullScreen:
                return 0
            }
        }()

        TabOverlayView(
            tabManager: tabManager,
            hiddenTabId: (activeTabViewState == .fullScreen || activeTabViewState.isTransitioning) ? activeTab?.id : nil,
            shrinkProgress: shrinkProgress,
            onSelectTab: { id in handleSelectTab(id: id) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(opacity)
        .animation(.linear(duration: 0.01), value: opacity)
        .allowsHitTesting(!activeTabViewState.isTransitioning)
    }

    @ViewBuilder
    private func activeTabLayer(geometry: GeometryProxy) -> some View {
        ZStack {
            if activeTabViewState == .fullScreen && !webViewReady {
                Color.black
                    .ignoresSafeArea()
            }
            if let tab = activeTab {
                let showLive = activeTabViewState == .fullScreen && webViewReady
                liveWebView(tab: tab, geometry: geometry)
                    .opacity(showLive ? 1 : 0)
                    .animation(.linear(duration: 0.01), value: showLive)
            }
        }
    }

    @ViewBuilder
    private func transitionLayer(geometry: GeometryProxy) -> some View {
        let opacity: Double = {
            guard activeTab != nil else { return 0 }
            switch activeTabViewState {
            case .shrinking:
                return 1
            case .expanding:
                return 1
            case .shrunk:
                return 0
            case .fullScreen:
                return 0
            }
        }()

        ZStack(alignment: .top) {
            transitionOverlay(geometry: geometry, progress: shrinkProgress)
        }
        .opacity(opacity)
        .animation(.easeOut(duration: 0.12), value: opacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func bottomBarLayer(geometry: GeometryProxy) -> some View {
        bottomBar()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .blur(radius: isReady ? 0 : 20)
            .opacity((bottomBarState == .submittingSearch || !webViewReady) ? 0 : 1)
    }

    @ViewBuilder
    private func navigationLayer(geometry: GeometryProxy) -> some View {
        if showNavigationCover {
            navigationCover(geometry: geometry)
        }
    }

    private var launchScreen: some View {
        ZStack {
            AppTheme.Colors.background
            AppTheme.Colors.accent.opacity(0.05)
            Rectangle().fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    @ViewBuilder
    private func liveWebView(tab: Tab, geometry: GeometryProxy) -> some View {
        HardenedWebView(
            viewModel: tab.viewModel,
            bottomInset: (bottomBarState == .search || bottomBarState == .browserSettings
                || bottomBarState == .siteSettings || bottomBarState == .knowledge)
                ? 0 : (bottomBarState == .hidden ? 20 : 80)
        )
        .id(tab.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .blur(radius: isReady ? 0 : 20)
        .allowsHitTesting(activeTabViewState == .fullScreen && webViewReady)
        .disabled(activeTabViewState != .fullScreen || !webViewReady)
        .onChange(of: tab.viewModel.scrollDelta) { _, delta in
            updateScrollState(delta: delta)
        }
    }

    @ViewBuilder
    private func transitionOverlay(geometry: GeometryProxy, progress: CGFloat) -> some View {
        let toolbarHeight: CGFloat = 80
        let targetScale: CGFloat = 0.72
        let cornerRadius: CGFloat = 16
        let headerHeight: CGFloat = 36

        let toolbarYPosition = geometry.size.height - toolbarHeight
        let cardHeight = min(geometry.size.height * targetScale, toolbarYPosition)
        let headerSpace = max(0, (toolbarYPosition - cardHeight) / 2)
        let cardCenterY = headerSpace + cardHeight / 2

        let currentY = lerp(geometry.size.height / 2, cardCenterY, progress)
        let currentScale = lerp(1.0, targetScale, progress)

        let currentHeaderTranslate = lerp(0, headerHeight / targetScale, progress)
        let lerpCornerRadius = lerp(0, cornerRadius, progress)

        let currentCardWidth = geometry.size.width * currentScale
        let currentCardHeight = geometry.size.height * currentScale
        let cardTopEdgeY = currentY - (currentCardHeight / 2)

        let visualGapHeight = currentHeaderTranslate * currentScale

        let titleOpacity: CGFloat = {
            switch activeTabViewState {
            case .shrinking:
                return lerp(0, 1, progress)
            case .expanding:
                return lerp(1, 0, progress)
            default:
                return 0
            }
        }()

        ZStack(alignment: .top) {
            if let tab = activeTab {
                tabCardHeader(tab: tab)
                    .frame(width: currentCardWidth, height: 36, alignment: .top)
                    .frame(height: max(0, visualGapHeight), alignment: .top)
                    .clipped()
                    .position(x: geometry.size.width / 2, y: cardTopEdgeY + (visualGapHeight / 2))
                    .zIndex(1)
                    .opacity(titleOpacity)
            }

            VStack(spacing: 0) {
                ZStack(alignment: .top) {

                    Color.clear
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)

                    Group {
                        if let backgroundColor = activeTab?.viewModel.themeColor {
                            Color(backgroundColor)
                        } else {
                            Color.black
                        }
                    }
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: lerpCornerRadius, bottomLeading: 0, bottomTrailing: 0, topTrailing: lerpCornerRadius)))
                    .offset(y: currentHeaderTranslate)
                }

                Group {
                    if let tab = activeTab, let snapshot = tab.snapshot {
                        Image(uiImage: snapshot)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        Color(white: 0.08)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask(RoundedRectangle(cornerRadius: lerpCornerRadius, style: .continuous))
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(currentScale, anchor: .center)
            .position(x: geometry.size.width / 2, y: currentY)
            .zIndex(2)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func navigationCover(geometry: GeometryProxy) -> some View {
        let startHeight = geometry.size.height * 0.67
        let targetHeight = geometry.size.height
        let height = lerp(startHeight, targetHeight, navigationCoverProgress)
        let cornerRadius: CGFloat = 39
        let overlayOpacity = lerp(0.35, 0.95, navigationCoverProgress)

        ZStack(alignment: .bottom) {
            Color.clear
            ZStack {
                BlurView(style: .systemChromeMaterial)
                Color.black.opacity(overlayOpacity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .cornerRadius(cornerRadius, corners: [.topLeft, .topRight])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .opacity(navigationCoverOpacity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func tabHeaderContent(tab: Tab) -> some View {
        HStack(spacing: 8) {
            let url = tab.viewModel.currentURL ?? tab.url
            if let url, let faviconURL = FaviconService.faviconURL(for: url) {
                AsyncImage(url: faviconURL) { phaseImage in
                    phaseImage.resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 16, height: 16)
            }

            Text(tab.title.isEmpty ? "New Tab" : tab.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    private func tabCardHeader(tab: Tab) -> some View {
        tabHeaderContent(tab: tab)
            .padding(.horizontal, 10)
            .frame(height: 36)
    }

    @ViewBuilder
    private func bottomBar() -> some View {
        let vm = activeTab?.viewModel
        let isOverlayVisible = activeTabViewState != .fullScreen && !tabManager.tabs.isEmpty
        BottomBarView(
            text: urlBinding,
            state: $bottomBarState,
            isFocused: $isAddressBarFocused,
            isLoading: vm?.isLoading ?? false,
            progress: vm?.estimatedProgress ?? 0,
            searchSuggestions: vm?.searchSuggestions ?? [],
            themeColor: vm?.themeColor,
            currentURL: vm?.currentURL,
            tabCount: tabManager.tabs.count,
            isTabOverlayVisible: isOverlayVisible,
            onTabsPressed: { Task { @MainActor in handleTabsPressed() } },
            onSettingsPressed: { Task { @MainActor in handleSettingsPressed() } },
            onSubmit: { Task { @MainActor in handleSubmit() } },
            onHistoryTap: { url in Task { @MainActor in handleHistoryTap(url: url) } },
            onSearchPressedInTabOverlay: { Task { @MainActor in handleSearchFromCarousel() } },
            onCopyUrl: { Task { @MainActor in handleCopyUrl() } },
            onReload: { Task { @MainActor in vm?.reload() } },
            onSuggestionTap: { suggestion in Task { @MainActor in handleSubmit(queryOverride: suggestion) } }
        )
    }

    private func handleTabsPressed() {
        guard !isTransitioning else { return }
        guard let activeTab = activeTab else { return }
        guard activeTabViewState == .fullScreen else { return }

        Task { @MainActor in
            let image = await activeTab.viewModel.captureSnapshot()
            if let image {
                activeTab.snapshot = image
            }

            activeTabViewState = .shrinking
            withAnimation(.smooth(duration: 0.28)) {
                self.shrinkProgress = 1.0
            } completion: {
                self.activeTabViewState = .shrunk
            }
        }
    }

    private func handleSelectTab(id: UUID) {
        guard !isTransitioning else { return }
        guard activeTabViewState == .shrunk else { return }
        guard tabManager.tabs.contains(where: { $0.id == id }) else { return }

        tabManager.switchTab(id: id)
        activeTabViewState = .expanding
        withAnimation(.smooth(duration: 0.28)) {
            self.shrinkProgress = 0.0
        } completion: {
            self.activeTabViewState = .fullScreen
        }
    }

    private func handleSearchFromCarousel() {
        guard !isTransitioning else { return }
        withAnimation(.smooth(duration: 0.3)) {
            bottomBarState = .search
        }
    }

    private func handleSettingsPressed() {
        withAnimation(.smooth(duration: 0.3)) {
            if bottomBarState == .browserSettings || bottomBarState == .siteSettings {
                bottomBarState = .collapsed
            } else {
                if activeTabViewState != .fullScreen {
                    bottomBarState = .browserSettings
                } else if let url = activeTab?.viewModel.currentURL,
                   !url.absoluteString.isEmpty,
                   url.absoluteString != "about:blank" {
                    bottomBarState = .siteSettings
                } else {
                    bottomBarState = .browserSettings
                }
            }
        }
    }

    private func handleSubmit(queryOverride: String? = nil) {
        let query = queryOverride ?? urlBinding.wrappedValue
        let tabsEmpty = tabManager.tabs.isEmpty
        let currentURLString = activeTab?.viewModel.currentURL?.absoluteString
        let hasValidPage = !tabsEmpty && (currentURLString != nil) && (currentURLString != "about:blank")

        isAddressBarFocused = false
        urlText = query

        withAnimation(.smooth(duration: 0.3)) {
            self.bottomBarState = .submittingSearch
            self.webViewReady = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)

            if (tabsEmpty || hasValidPage), let oldTab = activeTab {
                let image = await oldTab.viewModel.captureSnapshot()
                if let image { oldTab.snapshot = image }
            }

            if tabsEmpty || hasValidPage {
                tabManager.newTab()
            }

            activeTab?.viewModel.urlString = query
            activeTabViewState = .fullScreen
            shrinkProgress = 0

            let tabToLoad = activeTab
            await tabToLoad?.viewModel.processUserInput(query)

            withAnimation(.smooth(duration: 0.3)) {
                self.bottomBarState = .collapsed
            }

            if tabsEmpty {
                coverFinished = true
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            if !webViewReady {
                withAnimation(.smooth(duration: 0.4)) {
                    self.webViewReady = true
                }
            }
        }
    }

    private func handleHistoryTap(url: String) {
        handleSubmit(queryOverride: url)
    }

    private func handleCopyUrl() {
        if let validURL = activeTab?.viewModel.currentURL?.absoluteString,
           !validURL.isEmpty, validURL != "about:blank" {
            UIPasteboard.general.string = validURL
        } else {
            UIPasteboard.general.string = urlText
        }
        withAnimation(.smooth(duration: 0.3)) {
            bottomBarState = .collapsed
        }
    }

    private func beginNavigation() {
        coverFinished = false
        pageCommitted = false
        webViewReady = false

        triggerNavigationCover()
    }

    private func triggerNavigationCover() {
        showNavigationCover = true
        navigationCoverProgress = 0
        navigationCoverOpacity = 1

        withAnimation(.smooth(duration: 0.45)) {
            self.navigationCoverProgress = 1.0
        }
    }

    private func fadeInWebView() {
        withAnimation(.smooth(duration: 0.3)) {
            webViewReady = true
        }
    }

    private func updateScrollState(delta: CGFloat) {
        guard let viewModel = activeTab?.viewModel else { return }
        let offset = viewModel.scrollOffset

        if offset < 80 {
            scrollAnchor = offset
            wasScrollingDown = false
            if bottomBarState == .hidden {
                withAnimation(.smooth(duration: 0.3)) {
                    bottomBarState = .collapsed
                }
            }
            return
        }

        if delta > 0 {
            if !wasScrollingDown {
                scrollAnchor = offset
                wasScrollingDown = true
            }
            if offset - scrollAnchor >= 80 && bottomBarState == .collapsed {
                withAnimation(.smooth(duration: 0.3)) {
                    bottomBarState = .hidden
                }
            }
        } else if delta < -1 {
            wasScrollingDown = false
            scrollAnchor = offset
            if bottomBarState == .hidden {
                withAnimation(.smooth(duration: 0.3)) {
                    bottomBarState = .collapsed
                }
            }
        }
    }
}

fileprivate struct NavigationCoverChangeHandlers: ViewModifier {
    @Binding var showNavigationCover: Bool
    @Binding var navigationCoverOpacity: CGFloat
    @Binding var navigationCoverProgress: CGFloat
    @Binding var coverFinished: Bool
    @Binding var pageCommitted: Bool
    var onFadeIn: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: navigationCoverOpacity) { _, newValue in
                if newValue <= 0.01 && showNavigationCover {
                    showNavigationCover = false
                    navigationCoverOpacity = 1
                    navigationCoverProgress = 0
                    coverFinished = true
                    if pageCommitted { onFadeIn() }
                }
            }
            .onChange(of: pageCommitted) { _, committed in
                if committed && showNavigationCover && navigationCoverOpacity > 0.9 && navigationCoverProgress >= 0.99 {
                    withAnimation(.smooth(duration: 0.3)) {
                        navigationCoverOpacity = 0
                    }
                }
            }
    }
}

fileprivate struct PageLoadHandlers: ViewModifier {
    let pageReadyToken: Int
    let isActiveTabLoading: Bool
    let activeTabProgress: Double
    @Binding var webViewReady: Bool
    let coverFinished: Bool
    @Binding var pageCommitted: Bool
    @Binding var bottomBarState: BottomBarState
    var onFadeIn: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: pageReadyToken) { _, _ in
                pageCommitted = true
            }
            .onChange(of: isActiveTabLoading) { _, isLoading in
                guard bottomBarState != .submittingSearch else { return }

                if !isLoading && activeTabProgress >= 0.99 && !webViewReady {
                    pageCommitted = true
                    if coverFinished { onFadeIn() }
                }
            }
            .onChange(of: activeTabProgress) { _, progress in
                guard bottomBarState != .submittingSearch else { return }

                if progress >= 0.99 && !isActiveTabLoading && !webViewReady {
                    pageCommitted = true
                    if coverFinished { onFadeIn() }
                }
            }
            .onChange(of: coverFinished) { _, finished in
                guard finished && pageCommitted && !webViewReady else { return }
                guard bottomBarState != .submittingSearch else { return }
                onFadeIn()
            }
    }
}

fileprivate struct TabManagerHandlers: ViewModifier {
    let tabManager: TabManager
    @Binding var activeTabViewState: TabViewState
    @Binding var shrinkProgress: CGFloat
    @Binding var webViewReady: Bool
    @Binding var bottomBarState: BottomBarState

    func body(content: Content) -> some View {
        content
            .onChange(of: tabManager.tabs.isEmpty) { _, isEmpty in
                if isEmpty {
                    activeTabViewState = .fullScreen
                    shrinkProgress = 0
                    webViewReady = true
                    withAnimation(.smooth(duration: 0.3)) {
                        bottomBarState = .search
                    }
                }
            }
    }
}

fileprivate struct BottomBarFocusHandlers: ViewModifier {
    @Binding var bottomBarState: BottomBarState
    var isAddressBarFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: bottomBarState) { oldState, newState in
                if oldState != .search && newState == .search {
                    isAddressBarFocused.wrappedValue = true
                }
            }
    }
}

fileprivate struct ActiveTabChangedHandlers: ViewModifier {
    let tabManager: TabManager
    @Binding var bottomBarState: BottomBarState
    var isAddressBarFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: tabManager.activeTabId) { _, newId in
                if !tabManager.tabs.isEmpty {
                    isAddressBarFocused.wrappedValue = false
                }

                if bottomBarState == .submittingSearch { return }

                guard let newTab = tabManager.tabs.first(where: { $0.id == newId }) else {
                    withAnimation(.smooth(duration: 0.3)) { bottomBarState = .search }
                    return
                }

                let hasValidURL = newTab.viewModel.currentURL != nil
                let isActivelyLoading = newTab.viewModel.isLoading
                let hasPendingURL = !newTab.viewModel.urlString.isEmpty

                if hasValidURL || isActivelyLoading || hasPendingURL {
                    bottomBarState = .collapsed
                } else {
                    withAnimation(.smooth(duration: 0.3)) {
                        bottomBarState = .search
                    }
                }
            }
    }
}

fileprivate extension View {
    func applyNavigationCoverChangeHandlers(
        showNavigationCover: Binding<Bool>,
        navigationCoverOpacity: Binding<CGFloat>,
        navigationCoverProgress: Binding<CGFloat>,
        coverFinished: Binding<Bool>,
        pageCommitted: Binding<Bool>,
        onFadeIn: @escaping () -> Void
    ) -> some View {
        modifier(NavigationCoverChangeHandlers(
            showNavigationCover: showNavigationCover,
            navigationCoverOpacity: navigationCoverOpacity,
            navigationCoverProgress: navigationCoverProgress,
            coverFinished: coverFinished,
            pageCommitted: pageCommitted,
            onFadeIn: onFadeIn
        ))
    }

    func applyPageLoadHandlers(
        pageReadyToken: Int,
        isActiveTabLoading: Bool,
        activeTabProgress: Double,
        webViewReady: Binding<Bool>,
        coverFinished: Bool,
        pageCommitted: Binding<Bool>,
        bottomBarState: Binding<BottomBarState>,
        onFadeIn: @escaping () -> Void
    ) -> some View {
        modifier(PageLoadHandlers(
            pageReadyToken: pageReadyToken,
            isActiveTabLoading: isActiveTabLoading,
            activeTabProgress: activeTabProgress,
            webViewReady: webViewReady,
            coverFinished: coverFinished,
            pageCommitted: pageCommitted,
            bottomBarState: bottomBarState,
            onFadeIn: onFadeIn
        ))
    }

    func applyTabManagerHandlers(
        tabManager: TabManager,
        activeTabViewState: Binding<TabViewState>,
        shrinkProgress: Binding<CGFloat>,
        webViewReady: Binding<Bool>,
        bottomBarState: Binding<BottomBarState>
    ) -> some View {
        modifier(TabManagerHandlers(
            tabManager: tabManager,
            activeTabViewState: activeTabViewState,
            shrinkProgress: shrinkProgress,
            webViewReady: webViewReady,
            bottomBarState: bottomBarState
        ))
    }

    func applyBottomBarFocusHandlers(
        bottomBarState: Binding<BottomBarState>,
        isAddressBarFocused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(BottomBarFocusHandlers(
            bottomBarState: bottomBarState,
            isAddressBarFocused: isAddressBarFocused
        ))
    }

    func applyActiveTabChangedHandlers(
        tabManager: TabManager,
        bottomBarState: Binding<BottomBarState>,
        isAddressBarFocused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(ActiveTabChangedHandlers(
            tabManager: tabManager,
            bottomBarState: bottomBarState,
            isAddressBarFocused: isAddressBarFocused
        ))
    }
}

#Preview {
    BrowserView()
}
