import SwiftUI
import UIKit

struct BottomBarView: View {
    @Binding var text: String
    @Binding var state: BottomBarState
    @FocusState.Binding var isFocused: Bool
    var isLoading: Bool
    var progress: Double

    var searchSuggestions: [SearchSuggestion] = []
    var themeColor: UIColor?
    var currentURL: URL? = nil

    var tabCount: Int = 1
    var isTabOverlayVisible: Bool = false
    var onTabsPressed: () -> Void
    var onSettingsPressed: () -> Void
    var onSubmit: () -> Void
    var onHistoryTap: (String) -> Void
    var onSearchPressedInTabOverlay: (() -> Void)? = nil

    var onCopyUrl: () -> Void
    var onReload: () -> Void
    var onBack: () -> Void = {}
    var onForward: () -> Void = {}
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var onSuggestionTap: (String) -> Void

    var trackerCount: Int = 0
    var initialZoom: Int = 100
    var initialDesktopMode: Bool = false
    var onFindOnPage: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onZoomChanged: ((Int) -> Void)? = nil
    var onRequestDesktopSite: ((Bool) -> Void)? = nil
    var onReloadPage: (() -> Void)? = nil
    var onNavigate: ((String) -> Void)? = nil
    var onNewIncognitoTab: (() -> Void)? = nil
    var isIncognitoActive: Bool = false
    var backdropOpacity: CGFloat = 1

    @ObservedObject private var historyStore = HistoryStore.shared
    @ObservedObject private var searchHistoryStore = SearchHistoryStore.shared
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var animation
    @State private var isSpinning = false
    @State private var reloadRotation: Double = 0
    @State private var toolbarDragFraction: CGFloat = 0
    @State private var searchFieldOpacity: Double = 1.0
    @State private var magGlassOpacity: Double = 1.0
    @State private var gearIconOpacity: Double = 0.0
    @State private var folderIconOpacity: Double = 0.0

    var isExpanded: Bool {
        state == .search || state == .browserSettings || state == .siteSettings
            || state == .knowledge
    }

    var showsMagnifier: Bool {
        state == .collapsed || state == .hidden
            || state == .search || state == .submittingSearch
    }

    var expandedHeightRatio: CGFloat {
        if state == .submittingSearch { return 1.0 }
        return state == .knowledge ? 0.9 : 0.67
    }

    var body: some View {
        ResizableSheetContainer(
            isExpanded: Binding(
                get: {
                    state == .search || state == .browserSettings || state == .siteSettings
                        || state == .knowledge || state == .submittingSearch
                },
                set: { expanded in
                    if expanded {
                        if state == .collapsed || state == .hidden {
                            text = ""
                            state = .search
                        }
                    } else {
                        state = .collapsed
                    }
                }
            ),
            isCollapsed: Binding(
                get: { state == .hidden },
                set: { collapsed in
                    if collapsed {
                        state = .hidden
                    } else if state == .hidden {
                        state = .collapsed
                    }
                }
            ),
            isLoading: isLoading,
            progress: progress,
            expandedHeightRatio: expandedHeightRatio,
            themeColor: themeColor,
            backdropOpacity: backdropOpacity,
            onDragStart: {
                if state == .collapsed || state == .hidden {}
            },
            onExpand: {
                if state == .collapsed || state == .hidden {
                    text = ""
                    state = .search
                }

                withAnimation(AppTheme.Motion.sheet) {
                    toolbarDragFraction = 1.0
                }

                if state == .search {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isFocused = true
                    }
                }
            },
            onCollapse: {
                isFocused = false
                withAnimation(AppTheme.Motion.sheet) {
                    toolbarDragFraction = 0
                }
            },
            onDismissFocused: {
                isFocused = false
            },
            onDragProgress: { fraction in
                if fraction == 0 {
                    withAnimation(.smooth(duration: 0.3)) {
                        toolbarDragFraction = 0
                    }
                } else {
                    toolbarDragFraction = fraction
                }
            }
        ) {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    frostedBackground
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.text.opacity(0.15), lineWidth: 1))
                        .frame(width: isExpanded ? nil : 80, height: 44)
                        .padding(.top, 18)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                        .zIndex(0)

                    collapsedContent
                        .opacity(isExpanded ? 0 : 1)
                        .allowsHitTesting(!isExpanded)
                        .zIndex(1)

                    searchBarRow
                        .opacity(isExpanded ? 1 : 0)
                        .allowsHitTesting(isExpanded)
                        .zIndex(2)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(palette.text)
                        .frame(width: 18, height: 18)
                        .matchedGeometryEffect(
                            id: "magnifyingGlass_icon", in: animation, isSource: false
                        )
                        .opacity(magGlassOpacity)
                        .allowsHitTesting(false)
                }

                if state == .knowledge {
                    knowledgeContent
                        .id(state)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(AppTheme.Motion.fade.delay(0.15)),
                                removal: .opacity.animation(.easeOut(duration: 0.08))
                            )
                        )
                } else if state == .browserSettings || state == .siteSettings {
                    SettingsPage(
                        type: state == .browserSettings ? .browser : .site,
                        currentURL: currentURL,
                        onDismiss: { state = .collapsed },
                        trackerCount: trackerCount,
                        initialZoom: initialZoom,
                        initialDesktopMode: initialDesktopMode,
                        onFindOnPage: onFindOnPage,
                        onShare: onShare,
                        onZoomChanged: onZoomChanged,
                        onRequestDesktopSite: onRequestDesktopSite,
                        onReloadPage: onReloadPage,
                        onNavigate: onNavigate
                    )
                    .id(state)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.smooth(duration: 0.25).delay(0.15)),
                            removal: .opacity.animation(.smooth(duration: 0.05))
                        )
                    )
                } else {
                    searchSuggestionsArea
                        .allowsHitTesting(state == .search)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .opacity(isExpanded ? 1 : min(1, toolbarDragFraction * 2.0))
                }

                if state == .search || state == .collapsed || state == .hidden
                    || state == .browserSettings || state == .siteSettings
                {
                    Spacer(minLength: 0)
                }
            }
        }
        .animation(AppTheme.Motion.sheet, value: state)
        .ignoresSafeArea(.keyboard)
        .onChange(of: tabCount) { oldCount, newCount in
            guard newCount == 0, oldCount > 0 else { return }
            state = .search
        }
        .onChange(of: state) { _, newState in
            let isExpandingToSearch =
                newState == .search || newState == .browserSettings || newState == .siteSettings
                || newState == .knowledge
            let showsMag =
                newState == .collapsed || newState == .hidden
                || newState == .search || newState == .submittingSearch
            let showsGear = newState == .browserSettings
            let showsFolder = newState == .knowledge

            searchFieldOpacity = isExpandingToSearch ? 1.0 : 0.0
            magGlassOpacity = showsMag ? 1.0 : 0.0
            if !showsGear { gearIconOpacity = 0.0 }
            if !showsFolder { folderIconOpacity = 0.0 }

            if showsGear || showsFolder {
                withAnimation(.easeIn(duration: 0.22).delay(0.12)) {
                    if showsGear { gearIconOpacity = 1.0 }
                    if showsFolder { folderIconOpacity = 1.0 }
                }
            }

            if newState != .search {
                toolbarDragFraction = 0
                DispatchQueue.main.async {
                    isFocused = false
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect
            {
                withTransaction(Transaction(animation: nil)) {
                    keyboardHeight = frame.height
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            withTransaction(Transaction(animation: nil)) {
                keyboardHeight = 0
            }
        }
    }

    var searchBarRow: some View {
        HStack(spacing: 12) {

            ZStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Button {
                        Haptics.fire(.tap)
                        onCopyUrl()
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(palette.text.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Copy URL")

                    HStack(spacing: 2) {
                        Button {
                            Haptics.fire(.tap)
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(
                                    canGoBack ? palette.text : palette.text.opacity(0.2)
                                )
                                .frame(width: 28, height: 28)
                        }
                        .disabled(!canGoBack)
                        .accessibilityLabel("Back")

                        Button {
                            Haptics.fire(.tap)
                            onForward()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(
                                    canGoForward ? palette.text : palette.text.opacity(0.2)
                                )
                                .frame(width: 28, height: 28)
                        }
                        .disabled(!canGoForward)
                        .accessibilityLabel("Forward")
                    }
                    .padding(.horizontal, 2)
                    .clipShape(Capsule())
                }
                .frame(width: 96, alignment: .leading)
                .opacity(state == .siteSettings ? 1 : 0)
                .allowsHitTesting(state == .siteSettings)

                Button {
                    Haptics.fire(.tap)
                    onSettingsPressed()
                } label: {
                    ZStack {
                        Color.clear
                            .frame(width: 18, height: 18)
                            .matchedGeometryEffect(
                                id: "magnifyingGlass_icon",
                                in: animation,
                                isSource: isExpanded
                            )
                        Image(systemName: "gearshape.fill")
                            .opacity(gearIconOpacity)
                        Image(systemName: "folder.fill")
                            .opacity(folderIconOpacity)
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(palette.text.opacity(0.6))
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bottombar.settings.expanded")
                .accessibilityLabel("Settings")
                .opacity(state == .siteSettings ? 0 : 1)
                .allowsHitTesting(state != .siteSettings)
            }
            .frame(width: state == .siteSettings ? 96 : 44, height: 44, alignment: .leading)
            .clipped()

            ZStack(alignment: .leading) {
                if isFocused && state == .search && !ghostCompletion.isEmpty {
                    HStack(spacing: 0) {
                        Text(text)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.clear)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(ghostCompletion)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(palette.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .background(
                                Rectangle()
                                    .fill(palette.accent.opacity(0.30))
                            )
                        Spacer(minLength: 0)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                TextField(
                    state == .browserSettings ? "Browser Settings" : "Search...",
                    text: displayBinding
                )
                .accessibilityIdentifier("browser.urlField")
                .font(
                    (state == .browserSettings || state == .siteSettings || state == .knowledge)
                        ? AppTheme.Typography.display(size: 17, weight: .bold)
                        : AppTheme.Typography.sansBody(size: 17, weight: .bold)
                )
                .textFieldStyle(.plain)
                .foregroundColor(palette.text)
                .tint(palette.accent)
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    if isFocused && state == .search && !ghostCompletion.isEmpty {
                        text = text + ghostCompletion
                    }
                    Haptics.fire(.tap)
                    onSubmit()
                }
                .disabled(state == .siteSettings || state == .browserSettings || state == .knowledge)
                .truncationMode(
                    (state == .siteSettings || state == .browserSettings || state == .knowledge)
                        ? .tail : .head
                )
                .opacity(searchFieldOpacity)
            }
            .frame(height: 44)

            HStack(spacing: 0) {
                ZStack {
                    Button {
                        Haptics.fire(.tap)
                        onReload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .resizable()
                            .antialiased(true)
                            .scaledToFit()
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(palette.text.opacity(0.8))
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(reloadRotation), anchor: .center)
                            .frame(width: 44, height: 44)
                    }
                    .matchedGeometryEffect(id: "reloadButton", in: animation, isSource: isExpanded)
                    .opacity(state == .siteSettings ? 1 : 0)
                    .allowsHitTesting(state == .siteSettings)
                    .accessibilityLabel("Reload page")

                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(palette.text.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    .opacity(state == .search && !text.isEmpty ? 1 : 0)
                    .allowsHitTesting(state == .search && !text.isEmpty)
                    .accessibilityLabel("Clear search")
                }
                .frame(
                    width: state == .siteSettings || (state == .search && !text.isEmpty) ? 44 : 0,
                    height: 44)

                Button(action: {
                    Haptics.fire(.rigid)
                    onNewIncognitoTab?()
                }) {
                    ZStack {
                        Image(systemName: "eyes")
                            .opacity(isIncognitoActive ? 0 : 1)
                        ClosedEyes()
                            .opacity(isIncognitoActive ? 1 : 0)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(palette.text.opacity(isIncognitoActive ? 0.95 : 0.6))
                    .frame(width: 32, height: 44)
                    .animation(AppTheme.Motion.snappy, value: isIncognitoActive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isIncognitoActive ? "Switch to regular tab" : "Open incognito tab"
                )
                .opacity(state == .search ? 1 : 0)
                .allowsHitTesting(state == .search)
                .frame(width: state == .search ? 32 : 0)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .padding(.top, 18)
        .onChange(of: isLoading) { _, loading in
            if loading {
                if !isSpinning {
                    isSpinning = true
                    triggerSpin()
                }
            } else {
                isSpinning = false
            }
        }
    }

    var searchSuggestionsArea: some View {
        suggestionsList
    }

    private var suggestionsList: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasInput = !trimmed.isEmpty
        let lowered = trimmed.lowercased()

        let searchMatches: [SearchQueryEntry] = hasInput
            ? searchHistoryStore.suggestions(matching: trimmed, limit: 4)
            : Array(searchHistoryStore.entries.prefix(3))

        let urlMatches: [HistoryEntry] = {
            let raw: [HistoryEntry]
            if hasInput {
                let httpsPrefix = "https://" + lowered
                let httpPrefix = "http://" + lowered
                var prefixHits: [HistoryEntry] = []
                var substringHits: [HistoryEntry] = []
                prefixHits.reserveCapacity(8)
                substringHits.reserveCapacity(8)
                for entry in historyStore.entries {
                    let urlLower = entry.url.lowercased()
                    let titleLower = entry.title.lowercased()
                    if urlLower.hasPrefix(lowered) || urlLower.hasPrefix(httpsPrefix)
                        || urlLower.hasPrefix(httpPrefix)
                        || titleLower.hasPrefix(lowered) {
                        prefixHits.append(entry)
                    } else if urlLower.contains(lowered) || titleLower.contains(lowered) {
                        substringHits.append(entry)
                    }
                    if prefixHits.count + substringHits.count >= 8 { break }
                }
                raw = prefixHits + substringHits
            } else {
                raw = historyStore.recentEntries
            }

            var picked: [HistoryEntry] = []
            picked.reserveCapacity(4)
            for entry in raw {
                guard let url = URL(string: entry.url),
                      FaviconService.cachedFavicon(for: url) != nil else { continue }
                picked.append(entry)
                if picked.count >= 4 { break }
            }
            return picked
        }()

        var seenQueryKeys = Set<String>()
        for q in searchMatches {
            seenQueryKeys.insert(SearchHistoryStore.normalize(q.query))
        }

        let dedupedSuggestions = searchSuggestions.filter { suggestion in
            let key = SearchHistoryStore.normalize(suggestion.text)
            return !seenQueryKeys.contains(key)
        }

        let maxRows = 4
        let trimmedSearchMatches = Array(searchMatches.prefix(maxRows))
        let urlSlots = max(0, maxRows - trimmedSearchMatches.count)
        let trimmedUrlMatches = Array(urlMatches.prefix(urlSlots))
        let suggestionSlots = max(0, maxRows - trimmedSearchMatches.count - trimmedUrlMatches.count)
        let trimmedSuggestions = Array(dedupedSuggestions.prefix(suggestionSlots))

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(trimmedSearchMatches) { entry in
                    autofillRow(
                        icon: "clock.arrow.circlepath",
                        title: entry.query,
                        query: trimmed,
                        onTap: { onSuggestionTap(entry.query) }
                    )
                }

                ForEach(trimmedUrlMatches) { entry in
                    autofillURLRow(
                        url: URL(string: entry.url),
                        title: entry.title.isEmpty ? entry.url : entry.title,
                        query: trimmed,
                        onTap: { onHistoryTap(entry.url) }
                    )
                }

                ForEach(trimmedSuggestions, id: \.id) { suggestion in
                    SearchSuggestionRow(
                        suggestion: suggestion,
                        query: trimmed,
                        onTap: { onSuggestionTap(suggestion.text) }
                    )
                }
            }
            .frame(minHeight: 10)
            .transaction { $0.animation = nil }
        }
        .padding(.top, state == .search ? 0 : 12)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, isFocused ? keyboardHeight : 0, for: .scrollContent)
    }

    @ViewBuilder
    private func autofillRow(
        icon: String,
        title: String,
        query: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(palette.text.opacity(0.6))
                    .frame(width: 28)

                Text(autofillBolded(title, matching: query))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func autofillURLRow(
        url: URL?,
        title: String,
        query: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                FaviconView(url: url, size: 24, cornerRadius: 6)
                    .frame(width: 28)

                Text(autofillBolded(title, matching: query))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var ghostCompletion: String {
        guard state == .search, isFocused else { return "" }
        let typed = text
        let typedCount = typed.count
        guard typedCount >= 1 else { return "" }
        let lowered = typed.lowercased()

        for entry in searchHistoryStore.entries {
            let id = entry.id
            if id.count > typedCount, id.hasPrefix(lowered) {
                return String(entry.query.dropFirst(typedCount))
            }
        }

        for entry in historyStore.entries {
            let urlStr = entry.url
            let urlLower = urlStr.lowercased()
            if urlStr.count > typedCount, urlLower.hasPrefix(lowered) {
                return String(urlStr.dropFirst(typedCount))
            }
            let stripped = stripURLChrome(urlStr, lower: urlLower)
            if stripped.display.count > typedCount, stripped.lower.hasPrefix(lowered) {
                return String(stripped.display.dropFirst(typedCount))
            }
        }

        return ""
    }

    private func stripURLChrome(_ url: String, lower: String) -> (display: String, lower: String) {
        if lower.hasPrefix("https://www.") {
            return (String(url.dropFirst(12)), String(lower.dropFirst(12)))
        }
        if lower.hasPrefix("http://www.") {
            return (String(url.dropFirst(11)), String(lower.dropFirst(11)))
        }
        if lower.hasPrefix("https://") {
            return (String(url.dropFirst(8)), String(lower.dropFirst(8)))
        }
        if lower.hasPrefix("http://") {
            return (String(url.dropFirst(7)), String(lower.dropFirst(7)))
        }
        return (url, lower)
    }

    private func autofillBolded(_ text: String, matching query: String) -> AttributedString {
        var result = AttributedString(text)
        guard !query.isEmpty else { return result }
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: query, options: .caseInsensitive, range: searchRange) {
            if let attrRange = Range(range, in: result) {
                result[attrRange].font = .system(size: 16, weight: .heavy)
            }
            searchRange = range.upperBound..<text.endIndex
        }
        return result
    }

    @State private var keyboardHeight: CGFloat = 0

    private var frostedBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .environment(\.colorScheme, palette.isIncognito ? .dark : colorScheme)
            palette.uiElement.opacity(palette.isIncognito ? 0.45 : 0.65)
        }
    }

    private func triggerSpin() {
        guard isSpinning else { return }

        withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
            reloadRotation += 360
        } completion: {
            reloadRotation = reloadRotation.truncatingRemainder(dividingBy: 360)
        }
    }

    var collapsedContent: some View {
        let sideOpacity = isTabOverlayVisible ? 0.0 : 1.0

        return HStack(spacing: 0) {
            Button(action: onTabsPressed) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(palette.text.opacity(tabCount == 0 ? 0.35 : 1.0))
                        .frame(width: 44, height: 44)
                        .background(frostedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(palette.text.opacity(0.15), lineWidth: 1)
                        )
                }
            }
            .accessibilityIdentifier("bottombar.tabs")
            .disabled(tabCount == 0 || isTabOverlayVisible)
            .padding(.leading, 8)
            .opacity(sideOpacity)
            .allowsHitTesting(!isTabOverlayVisible)

            Spacer()

            Button(action: {
                if isTabOverlayVisible, let handler = onSearchPressedInTabOverlay {
                    handler()
                } else {
                    text = ""
                    state = .search
                }
            }) {
                ZStack {
                    Color.clear
                        .frame(width: 18, height: 18)
                        .matchedGeometryEffect(
                            id: "magnifyingGlass_icon", in: animation, isSource: !isExpanded
                        )

                    Image(systemName: "arrow.clockwise")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(palette.text)
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(0))
                        .opacity(0)
                        .matchedGeometryEffect(
                            id: "reloadButton", in: animation, isSource: !isExpanded)
                }
                .frame(width: 80, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("bottombar.searchOpen")

            Spacer()

            Button(action: onSettingsPressed) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(palette.text)
                    .frame(width: 44, height: 44)
                    .background(frostedBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(palette.text.opacity(0.15), lineWidth: 1)
                    )
            }
            .accessibilityIdentifier("bottombar.settings")
            .padding(.trailing, 8)
            .opacity(sideOpacity)
            .allowsHitTesting(!isTabOverlayVisible)
        }
        .frame(height: 80)
        .overlay(alignment: .topTrailing) {
            KnowledgeButton {
                state = .knowledge
            }
            .padding(.trailing, 16)
            .alignmentGuide(.top) { d in d[.bottom] }
            .opacity(isTabOverlayVisible ? 0 : 1)
            .allowsHitTesting(!isTabOverlayVisible)
        }
        .animation(AppTheme.Motion.micro, value: isTabOverlayVisible)
    }

    private var knowledgeContent: some View {
        KnowledgePanelView()
    }

    private var displayBinding: Binding<String> {
        Binding(
            get: {
                switch state {
                case .browserSettings:
                    return "Browser Settings"
                case .siteSettings:
                    return neaten(url: currentURL?.absoluteString ?? text)
                case .knowledge:
                    return "Knowledge"
                default:
                    return text
                }
            },
            set: { newValue in
                if state == .search {
                    text = newValue
                }
            }
        )
    }

    private func neaten(url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
            let host = urlComponents.host
        else {
            return url.isEmpty ? "Search..." : url
        }

        var cleanHost = host
        if cleanHost.hasPrefix("www.") {
            cleanHost.removeFirst(4)
        }
        return cleanHost
    }
}

private struct SearchSuggestionRow: View {
    let suggestion: SearchSuggestion
    let query: String
    let onTap: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(palette.text.opacity(0.6))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attributedText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(palette.text)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var attributedText: AttributedString {
        var result = AttributedString(suggestion.text)
        if !query.isEmpty {
            var searchRange = suggestion.text.startIndex..<suggestion.text.endIndex
            while let range = suggestion.text.range(of: query, options: .caseInsensitive, range: searchRange) {
                if let attrRange = Range(range, in: result) {
                    result[attrRange].font = .system(size: 16, weight: .heavy)
                }
                searchRange = range.upperBound..<suggestion.text.endIndex
            }
        }
        return result
    }
}

private struct ClosedEyesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lidWidth: CGFloat = 8
        let lidHeight: CGFloat = 5
        let gap: CGFloat = 3
        let totalWidth = lidWidth * 2 + gap
        let startX = (rect.width - totalWidth) / 2
        let y = rect.height / 2

        for i in 0..<2 {
            let x = startX + CGFloat(i) * (lidWidth + gap)
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(
                to: CGPoint(x: x + lidWidth, y: y),
                control: CGPoint(x: x + lidWidth / 2, y: y - lidHeight)
            )
        }
        return path
    }
}

private struct ClosedEyes: View {
    var body: some View {
        ClosedEyesShape()
            .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            .frame(width: 22, height: 16)
            .contentShape(Rectangle())
    }
}
