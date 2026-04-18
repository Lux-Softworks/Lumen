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

    @ObservedObject private var historyStore = HistoryStore.shared
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var animation
    @State private var isSpinning = false
    @State private var reloadRotation: Double = 0
    @State private var toolbarDragFraction: CGFloat = 0

    var isExpanded: Bool {
        state == .search || state == .browserSettings || state == .siteSettings
            || state == .knowledge || state == .submittingSearch
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
                    collapsedContent
                        .opacity(isExpanded ? 0 : 1)
                        .allowsHitTesting(!isExpanded)

                    searchBarRow
                        .opacity(isExpanded ? 1 : 0)
                        .allowsHitTesting(isExpanded)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(palette.text)
                        .frame(width: 18, height: 18)
                        .matchedGeometryEffect(
                            id: "magnifyingGlass_icon", in: animation, isSource: false
                        )
                        .opacity(showsMagnifier ? 1 : 0)
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
                        .opacity(isExpanded ? 1 : min(1, toolbarDragFraction * 2.0))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .clipped()
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
            withAnimation(AppTheme.Motion.sheet) {
                state = .search
            }
        }
        .onChange(of: state) { _, newState in
            if newState != .search {
                isFocused = false
                toolbarDragFraction = 0
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                as? CGRect
            {
                keyboardHeight = frame.height
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { _ in
            keyboardHeight = 0
        }
    }

    var searchBarRow: some View {
        HStack(spacing: 12) {

            ZStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Button(action: onCopyUrl) {
                        Image(systemName: "link")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(palette.text.opacity(0.8))
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    }

                    HStack(spacing: 2) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(canGoBack ? palette.text : palette.text.opacity(0.2))
                                .frame(width: 28, height: 28)
                        }
                        .disabled(!canGoBack)

                        Button(action: onForward) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(canGoForward ? palette.text : palette.text.opacity(0.2))
                                .frame(width: 28, height: 28)
                        }
                        .disabled(!canGoForward)
                    }
                    .padding(.horizontal, 2)
                    .clipShape(Capsule())
                }
                .frame(width: 96, alignment: .leading)
                .opacity(state == .siteSettings ? 1 : 0)
                .allowsHitTesting(state == .siteSettings)

                Button(action: onSettingsPressed) {
                    ZStack {
                        Color.clear
                            .frame(width: 18, height: 18)
                            .matchedGeometryEffect(
                                id: "magnifyingGlass_icon",
                                in: animation,
                                isSource: isExpanded
                            )
                        Image(systemName: "gearshape.fill")
                            .opacity(state == .browserSettings ? 1 : 0)
                        Image(systemName: "folder.fill")
                            .opacity(state == .knowledge ? 1 : 0)
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(palette.text.opacity(0.6))
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .opacity(state == .siteSettings ? 0 : 1)
                .allowsHitTesting(state != .siteSettings)
            }
            .frame(width: state == .siteSettings ? 96 : 44, height: 44, alignment: .leading)
            .clipped()

            TextField(
                state == .browserSettings ? "Browser Settings" : "Search...",
                text: displayBinding
            )
            .font(
                (state == .browserSettings || state == .siteSettings || state == .knowledge)
                    ? AppTheme.Typography.serifDisplay(size: 17, weight: .bold)
                    : AppTheme.Typography.sansBody(size: 17, weight: .bold)
            )
            .textFieldStyle(.plain)
            .foregroundColor(palette.text)
            .tint(palette.accent)
            .focused($isFocused)
            .submitLabel(.go)
            .onSubmit(onSubmit)
            .frame(height: 44)
            .disabled(state == .siteSettings || state == .browserSettings || state == .knowledge)
            .truncationMode(
                (state == .siteSettings || state == .browserSettings || state == .knowledge)
                    ? .tail : .head
            )

            HStack(spacing: 0) {
                ZStack {
                    Button(action: onReload) {
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

                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(palette.text.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    .opacity(state == .search && !text.isEmpty ? 1 : 0)
                    .allowsHitTesting(state == .search && !text.isEmpty)
                }
                .frame(width: state == .siteSettings || (state == .search && !text.isEmpty) ? 44 : 0, height: 44)

                Button(action: {
                    onNewIncognitoTab?()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                .accessibilityLabel(isIncognitoActive ? "Switch to regular tab" : "Open incognito tab")
                .opacity(state == .search ? 1 : 0)
                .allowsHitTesting(state == .search)
                .frame(width: state == .search ? 32 : 0)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            frostedBackground
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(palette.text.opacity(0.15), lineWidth: 1)
                )
                .matchedGeometryEffect(
                    id: "searchBackground_fill", in: animation, isSource: isExpanded)
        )
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
        ScrollView(.vertical, showsIndicators: false) {
            if !searchSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchSuggestions.enumerated()), id: \.element.id) {
                        index, suggestion in
                        Button {
                            onSuggestionTap(suggestion.text)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(palette.text.opacity(0.6))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    let attributedText: AttributedString = {
                                        var attributedText = AttributedString(
                                            suggestion.text)

                                        if !text.isEmpty {
                                            var searchRange =
                                                suggestion.text
                                                .startIndex..<suggestion.text.endIndex
                                            while let range = suggestion.text.range(
                                                of: text, options: .caseInsensitive,
                                                range: searchRange)
                                            {
                                                if let attrRange = Range(
                                                    range, in: attributedText)
                                                {
                                                    attributedText[attrRange].font =
                                                        .system(
                                                            size: 16, weight: .heavy)
                                                }
                                                searchRange =
                                                    range
                                                    .upperBound..<suggestion.text.endIndex
                                            }
                                        }

                                        return attributedText
                                    }()

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
                }
                .frame(minHeight: 10)
            } else if !historyStore.recentEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(
                        Array(historyStore.recentEntries.enumerated()), id: \.element.id
                    ) {
                        index, entry in
                        Button {
                            onHistoryTap(entry.url)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(palette.text.opacity(0.6))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
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
                }
                .frame(minHeight: 10)
            }
        }
        .padding(.top, state == .search ? 0 : 12)
        .scrollContentBackground(.hidden)
        .contentMargins(
            .bottom, (state == .search && isFocused) ? keyboardHeight : 0, for: .scrollContent)
    }

    @State private var keyboardHeight: CGFloat = 0

    private var frostedBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .environment(\.colorScheme, palette.isIncognito ? .dark : colorScheme)
            palette.uiElement.opacity(palette.isIncognito ? 0.55 : 0.75)
            palette.accent.opacity(0.04)
        }
    }

    private func triggerSpin() {
        guard isSpinning else { return }

        withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
            reloadRotation += 360
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
            .disabled(tabCount == 0)
            .padding(.leading, 8)
            .opacity(sideOpacity)
            .animation(AppTheme.Motion.micro, value: isTabOverlayVisible)

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
                    frostedBackground
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(palette.text.opacity(0.15), lineWidth: 1)
                        )
                        .matchedGeometryEffect(
                            id: "searchBackground_fill", in: animation, isSource: !isExpanded
                        )
                        .frame(width: 80, height: 44)

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
                }
            }

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
            .padding(.trailing, 8)
            .opacity(sideOpacity)
            .animation(AppTheme.Motion.micro, value: isTabOverlayVisible)
        }
        .frame(height: 80)
        .overlay(alignment: .topTrailing) {
            KnowledgeButton {
                state = .knowledge
            }
            .padding(.trailing, 16)
            .alignmentGuide(.top) { d in d[.bottom] }
            .opacity(isTabOverlayVisible ? 0 : 1)
            .animation(AppTheme.Motion.micro, value: isTabOverlayVisible)
        }
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
