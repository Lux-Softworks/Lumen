import SwiftUI
import UIKit

@MainActor
struct BrowserView: View {
    @Environment(\.palette) private var palette
    @StateObject private var tabManager = TabManager(createDefaultTab: false)
    @State private var bottomBarState: BottomBarState = .collapsed
    @State private var isReady = false
    @State private var activeTabViewState: TabViewState = .fullScreen
    @State private var shrinkProgress: CGFloat = 0
    @State private var scrollDownAccumulator: CGFloat = 0
    @State private var topBarOffset: CGFloat = 47
    @State private var cornerProgress: CGFloat = 0
    @State private var urlText: String = ""

    @State private var bottomBarOpacity: CGFloat = 1
    @State private var incognitoActive: Bool = false

    @State private var webViewReady = true
    @State private var coverFinished = false
    @State private var pageCommitted = false

    @State private var showNavigationCover = false
    @State private var navigationCoverProgress: CGFloat = 0
    @State private var tabSelectionOrigin: CGPoint? = nil
    @State private var tabOverlayResetToken: Int = 0
    @State private var pendingShrinkBelowId: UUID? = nil
    @State private var navigationCoverOpacity: CGFloat = 1

    @FocusState private var isAddressBarFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isTransitioning: Bool { activeTabViewState.isTransitioning }
    private var activeTab: Tab? { tabManager.activeTab }

    private func syncIncognitoToActiveTab() {
        let next = activeTab?.isIncognito ?? false
        guard next != incognitoActive else { return }

        Haptics.fire(.rigid)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            incognitoActive = next
        }
    }

    private var pageReadyToken: Int {
        activeTab?.viewModel.pageReadyToken ?? 0
    }

    private var firstPaintToken: Int {
        activeTab?.viewModel.firstPaintToken ?? 0
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

    private func updateState(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }

    var body: some View {
        content
            .environment(\.palette, incognitoActive ? .incognito : .standard)
            .ignoresSafeArea()
            .applyNavigationCoverChangeHandlers(
                showNavigationCover: $showNavigationCover,
                navigationCoverOpacity: $navigationCoverOpacity,
                navigationCoverProgress: $navigationCoverProgress,
                coverFinished: $coverFinished,
                pageCommitted: $pageCommitted,
                webViewReady: $webViewReady,
                onFadeIn: fadeInWebView
            )
            .applyPageLoadHandlers(
                pageReadyToken: pageReadyToken,
                firstPaintToken: firstPaintToken,
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
                tabManager: tabManager,
                bottomBarState: $bottomBarState,
                isAddressBarFocused: $isAddressBarFocused
            )
            .applyActiveTabChangedHandlers(
                tabManager: tabManager,
                activeTabViewState: $activeTabViewState,
                bottomBarState: $bottomBarState,
                webViewReady: $webViewReady,
                isAddressBarFocused: $isAddressBarFocused
            )
            .onChange(of: tabManager.activeTabId) { _, _ in syncIncognitoToActiveTab() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    SearchHistoryStore.shared.flush()
                }
            }
            .onChange(of: tabManager.tabs.count) { old, new in
                guard new < old else { return }
                urlText = ""
                activeTab?.viewModel.urlString = ""
            }
            .onOpenURL { url in
                tabManager.openExternalURL(url)
            }
            .onAppear {
                wireDownloadHandler()
                DispatchQueue.main.async {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                        isReady = true
                    }
                    withAnimation(reduceMotion ? nil : AppTheme.Motion.sheet) {
                        bottomBarState = .search
                    }
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
            knowledgeIndicatorLayer(geometry: geometry)
                .zIndex(9)
            navigationLayer(geometry: geometry)
                .zIndex(10)
            bottomBarLayer(geometry: geometry)
                .zIndex(11)
            if !isReady {
                launchScreen.zIndex(200)
            }
        }
    }

    @ViewBuilder
    private func backgroundLayer(geometry: GeometryProxy) -> some View {
        VibrantBackground(size: geometry.size, isIncognito: incognitoActive)
    }

    @ViewBuilder
    private func tabOverlayLayer() -> some View {
        let opacity: Double = {
            switch activeTabViewState {
            case .shrinking:
                return 1
            case .expanding:
                return 1
            case .shrunk:
                return 1
            case .fullScreen:
                return 0
            }
        }()

        TabOverlayView(
            tabManager: tabManager,
            hiddenTabId: (activeTabViewState == .fullScreen || activeTabViewState.isTransitioning)
                ? activeTab?.id : nil,
            shrinkProgress: shrinkProgress,
            resetToken: tabOverlayResetToken,
            pendingShrinkBelowId: pendingShrinkBelowId,
            onSelectTab: { id, origin in handleSelectTab(id: id, origin: origin) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(opacity)
        .allowsHitTesting(!activeTabViewState.isTransitioning)
    }

    @ViewBuilder
    private func activeTabLayer(geometry: GeometryProxy) -> some View {
        let isFullScreen = activeTabViewState == .fullScreen

        ZStack {
            if let tab = activeTab {
                (tab.themeColor.map { Color(uiColor: $0) } ?? Color.black)
                    .ignoresSafeArea()

                let showLive = isFullScreen && webViewReady
                liveWebView(tab: tab, geometry: geometry)
                    .opacity(showLive ? 1 : 0)
                    .dynamicTypeSize(.large)
            } else if tabManager.tabs.isEmpty && bottomBarState == .submittingSearch {
                Color.black
                    .ignoresSafeArea()
            } else if tabManager.tabs.isEmpty {
                HomeHeroView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .opacity(isFullScreen ? 1 : 0)
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
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func bottomBarLayer(geometry: GeometryProxy) -> some View {
        bottomBar()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .opacity(bottomBarState == .submittingSearch ? 0 : bottomBarOpacity)
            .allowsHitTesting(activeTabViewState != .expanding)
    }

    @ViewBuilder
    private func navigationLayer(geometry: GeometryProxy) -> some View {
        if showNavigationCover {
            navigationCover(geometry: geometry)
        }
    }

    @ViewBuilder
    private func knowledgeIndicatorLayer(geometry: GeometryProxy) -> some View {
        KnowledgeCaptureIndicator()
            .padding(.top, getStatusBarHeight(geometry) + 8)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)
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
                ? 0 : (bottomBarState == .hidden ? 20 : 80),
            safeAreaTop: getStatusBarHeight(geometry)
        )
        .id(tab.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .allowsHitTesting(activeTabViewState == .fullScreen && webViewReady)
        .disabled(activeTabViewState != .fullScreen || !webViewReady)
        .onAppear {
            let statusBarHeight = getStatusBarHeight(geometry)
            topBarOffset = statusBarHeight
            scrollDownAccumulator = 0

            tab.viewModel.onScrollUpdate = { offset, delta, contentHeight, frameHeight in
                guard bottomBarState == .collapsed || bottomBarState == .hidden else { return }

                let maxScroll = contentHeight - frameHeight
                let statusBarHeight = getStatusBarHeight(geometry)

                if offset < 100 {
                    updateState { scrollDownAccumulator = 0 }
                    if topBarOffset != statusBarHeight || bottomBarState == .hidden {
                        updateState {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                                topBarOffset = statusBarHeight
                                bottomBarState = .collapsed
                            }
                        }
                    }
                    if offset <= 0 { return }
                }

                if contentHeight > 0 && offset >= maxScroll - 5 {
                    updateState { scrollDownAccumulator = 0 }
                    return
                }

                if delta > 3 && offset > 30 && topBarOffset != 0 {
                    updateState {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                            topBarOffset = 0
                        }
                    }
                } else if delta < -5 && topBarOffset == 0 {
                    updateState {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                            topBarOffset = statusBarHeight
                        }
                    }
                }

                if delta > 3 {
                    updateState { scrollDownAccumulator = min(scrollDownAccumulator + delta, 300) }
                    if scrollDownAccumulator > 120 && bottomBarState == .collapsed {
                        updateState {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                                bottomBarState = .hidden
                            }
                        }
                    }
                } else if delta < -10 {
                    updateState { scrollDownAccumulator = 0 }
                    if bottomBarState == .hidden {
                        updateState {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                                bottomBarState = .collapsed
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            tab.viewModel.onScrollUpdate = nil
        }
        .onChange(of: tab.viewModel.pageReadyToken) { _, _ in
            updateState { scrollDownAccumulator = 0 }
            updateState {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                    topBarOffset = getStatusBarHeight(geometry)
                    let currentURL = tab.viewModel.currentURL?.absoluteString ?? ""
                    let isBlank = currentURL.isEmpty || currentURL == "about:blank"

                    if !isBlank && bottomBarState != .search && bottomBarState != .browserSettings
                        && bottomBarState != .siteSettings && bottomBarState != .knowledge
                    {
                        bottomBarState = .collapsed
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func transitionOverlay(geometry: GeometryProxy, progress: CGFloat) -> some View {
        let toolbarHeight: CGFloat = 80
        let baseTargetScale: CGFloat = 0.69
        let multiTabBoost: CGFloat = tabManager.tabs.count > 1 ? 1.02 : 1.0
        let targetScale: CGFloat = baseTargetScale * multiTabBoost
        let cornerRadius: CGFloat = 16
        let headerHeight: CGFloat = 36

        let toolbarYPosition = geometry.size.height - toolbarHeight
        let cardHeight = min(geometry.size.height * targetScale, toolbarYPosition)
        let headerSpace = max(0, (toolbarYPosition - cardHeight) / 2)
        let cardCenterY = headerSpace + cardHeight / 2

        let centerX = geometry.size.width / 2
        let originX = tabSelectionOrigin?.x ?? centerX
        let originY = tabSelectionOrigin?.y ?? cardCenterY

        let currentX = lerp(centerX, originX, progress)
        let currentY = lerp(geometry.size.height / 2, originY, progress)
        let currentScale = lerp(1.0, targetScale, progress)
        let lerpCornerRadius = lerp(0, cornerRadius / targetScale, progress)
        let delayedCornerRadius = lerp(0, cornerRadius / targetScale, cornerProgress)

        let currentCardWidth = geometry.size.width * currentScale
        let currentCardHeight = geometry.size.height * currentScale
        let cardTopEdgeY = currentY - (currentCardHeight / 2)

        let currentHeaderTranslate = lerp(0, headerHeight / baseTargetScale, progress)
        let headerSlotHeight = lerp(
            getStatusBarHeight(geometry), headerHeight / baseTargetScale, progress)
        let _ = currentHeaderTranslate * currentScale

        let isMultiTab = tabManager.tabs.count > 1
        let titleOpacity: CGFloat = {
            switch activeTabViewState {
            case .shrinking:
                return isMultiTab ? lerp(1, 0, progress) : min(1, max(0, progress * 5))
            case .expanding:
                return lerp(1, 0, progress)
            default:
                return 0
            }
        }()

        ZStack(alignment: .top) {
            if let tab = activeTab {
                tabHeaderContent(tab: tab, textOpacity: titleOpacity)
                    .padding(.horizontal, 10)
                    .frame(width: currentCardWidth, height: headerHeight)
                    .position(x: currentX, y: cardTopEdgeY + (headerHeight / 2) - 2)
                    .zIndex(1)
            }

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(height: headerSlotHeight)
                        .frame(maxWidth: .infinity)

                    headerStripColor(tab: activeTab)
                        .clipShape(
                            UnevenRoundedRectangle(
                                cornerRadii: .init(
                                    topLeading: lerpCornerRadius,
                                    bottomLeading: 0,
                                    bottomTrailing: 0,
                                    topTrailing: lerpCornerRadius
                                ),
                                style: .continuous
                            )
                        )
                        .offset(y: currentHeaderTranslate)
                }

                ZStack {
                    if let tab = activeTab, let snapshot = tab.snapshot {
                        Image(uiImage: snapshot)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.08)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(
                            topLeading: delayedCornerRadius,
                            bottomLeading: lerpCornerRadius,
                            bottomTrailing: lerpCornerRadius,
                            topTrailing: delayedCornerRadius
                        ),
                        style: .continuous
                    )
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(currentScale, anchor: .center)
            .position(x: currentX, y: currentY)
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
                Rectangle().fill(.regularMaterial)
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
    private func tabHeaderContent(tab: Tab, textOpacity: CGFloat = 1) -> some View {
        TabHeaderLabel(
            title: tab.title,
            url: tab.viewModel.currentURL ?? tab.url,
            isIncognito: tab.isIncognito,
            textOpacity: textOpacity,
            iconSize: 20,
            contrastBackground: tab.themeColor
        )
    }

    @ViewBuilder
    private func headerStripColor(tab: Tab?) -> some View {
        if let themeColor = tab?.viewModel.themeColor {
            Color(themeColor)
        } else {
            Color.clear
        }
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
            onTabsPressed: handleTabsPressed,
            onSettingsPressed: handleSettingsPressed,
            onSubmit: { handleSubmit() },
            onHistoryTap: { url in handleHistoryTap(url: url) },
            onSearchPressedInTabOverlay: handleSearchFromCarousel,
            onCopyUrl: handleCopyUrl,
            onReload: {
                vm?.reload()
            },
            onBack: { vm?.goBack() },
            onForward: { vm?.goForward() },
            canGoBack: vm?.canGoBack ?? false,
            canGoForward: vm?.canGoForward ?? false,
            onSuggestionTap: { suggestion in
                handleSubmit(queryOverride: suggestion)
            },
            trackerCount: vm?.blockedTrackersCount ?? 0,
            initialZoom: vm?.currentZoomPercent ?? 100,
            initialDesktopMode: vm?.isDesktopMode ?? false,
            onFindOnPage: {
                vm?.activateFindOnPage()
            },
            onShare: {
                guard let url = vm?.currentURL else { return }
                let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                    let root = scene.keyWindow?.rootViewController
                {
                    root.present(vc, animated: true)
                }
            },
            onZoomChanged: { percent in
                vm?.applyZoom(percent)
            },
            onRequestDesktopSite: { on in
                vm?.setDesktopMode(on)
            },
            onReloadPage: {
                vm?.reload()
            },
            onNavigate: { url in
                vm?.navigate(to: url)
                bottomBarState = .collapsed
            },
            onNewIncognitoTab: handleNewIncognitoTab,
            isIncognitoActive: incognitoActive,
            backdropOpacity: bottomBarState == .search
                ? 1
                : max(0, min(1, 1 - shrinkProgress))
        )
    }

    private func wireDownloadHandler() {
        if #available(iOS 14.5, *) {
            DownloadHandler.onDownloadComplete = { [weak tabManager] fileURL in
                guard let tabManager else { return }
                Task { @MainActor in
                    let incognito = tabManager.activeTab?.isIncognito ?? false
                    tabManager.newTab(incognito: incognito)
                    tabManager.activeTab?.viewModel.loadURL(fileURL)
                }
            }
        }
    }

    private func handleNewIncognitoTab() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            incognitoActive.toggle()
        }
    }

    private func handleTabsPressed() {
        guard !isTransitioning else { return }
        guard let activeTab = activeTab else { return }
        guard activeTabViewState == .fullScreen else { return }

        Task { @MainActor in
            let image = await activeTab.viewModel.captureSnapshot()

            guard self.activeTabViewState == .fullScreen else { return }

            if let image {
                activeTab.snapshot = image
            }

            if tabManager.tabs.count > 1, let below = tabManager.tabBelowActive {
                pendingShrinkBelowId = below.id
                tabSelectionOrigin = computeRightLandingPoint()
            } else {
                pendingShrinkBelowId = nil
                tabSelectionOrigin = nil
            }

            activeTabViewState = .shrinking

            withAnimation(reduceMotion ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) {
                self.shrinkProgress = 1.0
            } completion: {
                self.activeTabViewState = .shrunk
                self.pendingShrinkBelowId = nil
            }
            withAnimation(reduceMotion ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.21).delay(0.14)) {
                self.cornerProgress = 1.0
            }
        }
    }

    private func computeRightLandingPoint() -> CGPoint {
        let screen = UIScreen.main.bounds.size
        let toolbarHeight: CGFloat = 80
        let targetScale: CGFloat = 0.69
        let toolbarYPosition = screen.height - toolbarHeight
        let cardHeight = min(screen.height * targetScale, toolbarYPosition)
        let headerSpace = max(0, (toolbarYPosition - cardHeight) / 2)
        let cardCenterY = headerSpace + cardHeight / 2
        let centerX = screen.width / 2
        let cardWidth = screen.width * targetScale
        let landingX = centerX + cardWidth * 0.90
        return CGPoint(x: landingX, y: cardCenterY)
    }

    private func handleSelectTab(id: UUID, origin: CGPoint? = nil) {
        guard !isTransitioning else { return }
        guard activeTabViewState == .shrunk else { return }
        guard tabManager.tabs.contains(where: { $0.id == id }) else { return }

        tabSelectionOrigin = origin
        tabManager.switchTab(id: id)
        activeTabViewState = .expanding

        withAnimation(reduceMotion ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) {
            self.shrinkProgress = 0.0
        } completion: {
            self.tabManager.moveActiveTabToTop()
            self.activeTabViewState = .fullScreen
            self.webViewReady = true
            self.tabSelectionOrigin = nil
            self.tabOverlayResetToken &+= 1
        }
        withAnimation(reduceMotion ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.14)) {
            self.cornerProgress = 0.0
        }
    }

    private func handleSearchFromCarousel() {
        guard !isTransitioning else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            bottomBarState = .search
        }
    }

    private func handleSettingsPressed() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            if bottomBarState == .browserSettings || bottomBarState == .siteSettings {
                bottomBarState = .collapsed
            } else {
                if activeTabViewState != .fullScreen {
                    bottomBarState = .browserSettings
                } else if let url = activeTab?.viewModel.currentURL,
                    !url.absoluteString.isEmpty,
                    url.absoluteString != "about:blank"
                {
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
        let hasValidPage =
            !tabsEmpty && (currentURLString != nil) && (currentURLString != "about:blank")

        isAddressBarFocused = false
        urlText = query

        recordSearchQueryIfNeeded(query)

        beginNavigation()

        DispatchQueue.main.async {
            self.updateState {
                withAnimation(self.reduceMotion ? nil : .smooth(duration: 0.3)) {
                    self.bottomBarState = .submittingSearch
                    self.bottomBarOpacity = 0
                    self.webViewReady = false
                }
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))

            if tabsEmpty || hasValidPage, let oldTab = activeTab {
                let image = await oldTab.viewModel.captureSnapshot()
                if let image { oldTab.snapshot = image }
            }

            if tabsEmpty || hasValidPage {
                tabManager.newTab(incognito: incognitoActive)
            }

            activeTab?.viewModel.urlString = query
            activeTabViewState = .fullScreen
            shrinkProgress = 0
            let tabToLoad = activeTab

            await tabToLoad?.viewModel.processUserInput(query)

            withTransaction(Transaction(animation: nil)) {
                self.bottomBarState = .collapsed
            }

            if tabsEmpty {
                coverFinished = true
            }

            try? await Task.sleep(for: .seconds(0.25))
            updateState {
                withAnimation(self.reduceMotion ? nil : .linear(duration: 0.15)) {
                    self.bottomBarOpacity = 1
                }
            }
        }
    }

    private func handleHistoryTap(url: String) {
        handleSubmit(queryOverride: url)
    }

    private func recordSearchQueryIfNeeded(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, !incognitoActive else { return }
        if looksLikeURL(trimmed) { return }
        SearchHistoryStore.shared.record(query: trimmed, isIncognito: incognitoActive)
    }

    private func looksLikeURL(_ s: String) -> Bool {
        guard !s.contains(" ") else { return false }
        if let parsed = URL(string: s), parsed.scheme != nil,
           parsed.host != nil || parsed.scheme == "about" {
            return true
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-/_~"))
        guard s.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        let host = s.split(separator: "/", maxSplits: 1).first.map(String.init) ?? s
        let parts = host.split(separator: ".")
        guard parts.count >= 2, let tld = parts.last else { return false }
        return tld.count >= 2 && tld.count <= 24 && tld.allSatisfy { $0.isLetter }
    }

    private func handleCopyUrl() {
        if let validURL = activeTab?.viewModel.currentURL?.absoluteString,
            !validURL.isEmpty, validURL != "about:blank"
        {
            UIPasteboard.general.string = validURL
        } else {
            UIPasteboard.general.string = urlText
        }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            bottomBarState = .collapsed
        }
    }

    private func beginNavigation() {
        updateState {
            coverFinished = false
            pageCommitted = false
            webViewReady = false
        }

        triggerNavigationCover()
    }

    private func triggerNavigationCover() {
        updateState {
            showNavigationCover = true
            navigationCoverProgress = 0
            navigationCoverOpacity = 1
        }

        updateState {
            withAnimation(self.reduceMotion ? nil : .timingCurve(0.32, 0.72, 0, 1, duration: 0.30)) {
                self.navigationCoverProgress = 1.0
            }
        }
    }

    private func fadeInWebView() {
        updateState {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                webViewReady = true
            }
        }
    }

}

private struct NavigationCoverChangeHandlers: ViewModifier {
    @Binding var showNavigationCover: Bool
    @Binding var navigationCoverOpacity: CGFloat
    @Binding var navigationCoverProgress: CGFloat
    @Binding var coverFinished: Bool
    @Binding var pageCommitted: Bool
    @Binding var webViewReady: Bool
    var onFadeIn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onChange(of: navigationCoverOpacity) { _, newValue in
                if newValue <= 0.01 && showNavigationCover {
                    showNavigationCover = false
                    navigationCoverOpacity = 1
                    navigationCoverProgress = 0
                    coverFinished = true
                }
            }
            .onChange(of: webViewReady) { _, ready in
                if ready && showNavigationCover && navigationCoverOpacity > 0.9 {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                        navigationCoverOpacity = 0
                    }
                }
            }
    }
}

private struct PageLoadHandlers: ViewModifier {
    let pageReadyToken: Int
    let firstPaintToken: Int
    let isActiveTabLoading: Bool
    let activeTabProgress: Double
    @Binding var webViewReady: Bool
    let coverFinished: Bool
    @Binding var pageCommitted: Bool
    @Binding var bottomBarState: BottomBarState
    var onFadeIn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onChange(of: pageReadyToken) { _, _ in
                pageCommitted = true
                if bottomBarState == .hidden {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                        bottomBarState = .collapsed
                    }
                }
                if !webViewReady {
                    onFadeIn()
                }
            }
            .onChange(of: firstPaintToken) { _, _ in
                guard !webViewReady else { return }
                onFadeIn()
            }
            .onChange(of: isActiveTabLoading) { _, isLoading in
                guard bottomBarState != .submittingSearch else { return }

                if !isLoading && activeTabProgress >= 0.99 && !webViewReady {
                    pageCommitted = true
                }
            }
            .onChange(of: activeTabProgress) { _, progress in
                guard bottomBarState != .submittingSearch else { return }

                if progress >= 0.99 && !isActiveTabLoading && !webViewReady {
                    pageCommitted = true
                }
            }
            .onChange(of: coverFinished) { _, finished in
                guard finished && pageCommitted && !webViewReady else { return }
                guard bottomBarState != .submittingSearch else { return }
                onFadeIn()
            }
    }
}

private struct TabManagerHandlers: ViewModifier {
    let tabManager: TabManager
    @Binding var activeTabViewState: TabViewState
    @Binding var shrinkProgress: CGFloat
    @Binding var webViewReady: Bool
    @Binding var bottomBarState: BottomBarState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onChange(of: tabManager.tabs.isEmpty) { _, isEmpty in
                if isEmpty {
                    DispatchQueue.main.async {
                        withAnimation(reduceMotion ? nil : AppTheme.Motion.sheet) {
                            bottomBarState = .search
                        }
                        activeTabViewState = .fullScreen
                        shrinkProgress = 0
                        webViewReady = true
                    }
                }
            }
    }
}

private struct BottomBarFocusHandlers: ViewModifier {
    let tabManager: TabManager
    @Binding var bottomBarState: BottomBarState
    var isAddressBarFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .onChange(of: bottomBarState) { oldState, newState in
                if oldState != .search && newState == .search {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isAddressBarFocused.wrappedValue = true
                    }
                }
            }
    }
}

private struct ActiveTabChangedHandlers: ViewModifier {
    let tabManager: TabManager
    @Binding var activeTabViewState: TabViewState
    @Binding var bottomBarState: BottomBarState
    @Binding var webViewReady: Bool
    var isAddressBarFocused: FocusState<Bool>.Binding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onChange(of: tabManager.activeTabId) { _, newId in
                if !tabManager.tabs.isEmpty {
                    DispatchQueue.main.async {
                        isAddressBarFocused.wrappedValue = false
                    }
                }

                if bottomBarState == .submittingSearch { return }

                if activeTabViewState == .shrunk || activeTabViewState == .expanding {
                    return
                }

                guard let newTab = tabManager.tabs.first(where: { $0.id == newId }) else {
                    if !tabManager.tabs.isEmpty {
                        DispatchQueue.main.async {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { bottomBarState = .search }
                        }
                    }
                    return
                }

                let hasValidURL = newTab.viewModel.currentURL != nil
                let isActivelyLoading = newTab.viewModel.isLoading
                let hasPendingURL = !newTab.viewModel.urlString.isEmpty

                if hasValidURL || isActivelyLoading || hasPendingURL {
                    DispatchQueue.main.async {
                        webViewReady = true
                        bottomBarState = .collapsed
                    }
                } else {
                    bottomBarState = .search
                }
            }
    }
}

extension View {
    fileprivate func applyNavigationCoverChangeHandlers(
        showNavigationCover: Binding<Bool>,
        navigationCoverOpacity: Binding<CGFloat>,
        navigationCoverProgress: Binding<CGFloat>,
        coverFinished: Binding<Bool>,
        pageCommitted: Binding<Bool>,
        webViewReady: Binding<Bool>,
        onFadeIn: @escaping () -> Void
    ) -> some View {
        modifier(
            NavigationCoverChangeHandlers(
                showNavigationCover: showNavigationCover,
                navigationCoverOpacity: navigationCoverOpacity,
                navigationCoverProgress: navigationCoverProgress,
                coverFinished: coverFinished,
                pageCommitted: pageCommitted,
                webViewReady: webViewReady,
                onFadeIn: onFadeIn
            ))
    }

    fileprivate func applyPageLoadHandlers(
        pageReadyToken: Int,
        firstPaintToken: Int,
        isActiveTabLoading: Bool,
        activeTabProgress: Double,
        webViewReady: Binding<Bool>,
        coverFinished: Bool,
        pageCommitted: Binding<Bool>,
        bottomBarState: Binding<BottomBarState>,
        onFadeIn: @escaping () -> Void
    ) -> some View {
        modifier(
            PageLoadHandlers(
                pageReadyToken: pageReadyToken,
                firstPaintToken: firstPaintToken,
                isActiveTabLoading: isActiveTabLoading,
                activeTabProgress: activeTabProgress,
                webViewReady: webViewReady,
                coverFinished: coverFinished,
                pageCommitted: pageCommitted,
                bottomBarState: bottomBarState,
                onFadeIn: onFadeIn
            ))
    }

    fileprivate func applyTabManagerHandlers(
        tabManager: TabManager,
        activeTabViewState: Binding<TabViewState>,
        shrinkProgress: Binding<CGFloat>,
        webViewReady: Binding<Bool>,
        bottomBarState: Binding<BottomBarState>
    ) -> some View {
        modifier(
            TabManagerHandlers(
                tabManager: tabManager,
                activeTabViewState: activeTabViewState,
                shrinkProgress: shrinkProgress,
                webViewReady: webViewReady,
                bottomBarState: bottomBarState
            ))
    }

    fileprivate func applyBottomBarFocusHandlers(
        tabManager: TabManager,
        bottomBarState: Binding<BottomBarState>,
        isAddressBarFocused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(
            BottomBarFocusHandlers(
                tabManager: tabManager,
                bottomBarState: bottomBarState,
                isAddressBarFocused: isAddressBarFocused
            ))
    }

    fileprivate func applyActiveTabChangedHandlers(
        tabManager: TabManager,
        activeTabViewState: Binding<TabViewState>,
        bottomBarState: Binding<BottomBarState>,
        webViewReady: Binding<Bool>,
        isAddressBarFocused: FocusState<Bool>.Binding
    ) -> some View {
        modifier(
            ActiveTabChangedHandlers(
                tabManager: tabManager,
                activeTabViewState: activeTabViewState,
                bottomBarState: bottomBarState,
                webViewReady: webViewReady,
                isAddressBarFocused: isAddressBarFocused
            ))
    }
}

#Preview {
    BrowserView()
}
