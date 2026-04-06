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
    var onSuggestionTap: (String) -> Void

    @ObservedObject private var historyStore = HistoryStore.shared

    @Namespace private var animation
    @State private var showHistory = false
    @State private var reloadRotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var toolbarDragFraction: CGFloat = 0
    @State private var suggestionsExpanded = false
    @State private var suggestionsOpacity: Double = 0

    var isExpanded: Bool {
        state == .search || state == .browserSettings || state == .siteSettings || state == .knowledge || state == .submittingSearch
    }
    var expandedHeightRatio: CGFloat {
        if state == .submittingSearch { return 1.0 }
        return state == .knowledge ? 0.9 : 0.67
    }

    var body: some View {
        ResizableSheetContainer(
            isExpanded: Binding(
                get: { state == .search || state == .browserSettings || state == .siteSettings || state == .knowledge || state == .submittingSearch },
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

                if state == .search {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isFocused = true
                    }
                }
            },
            onCollapse: {
                isFocused = false
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
                }

                if state == .knowledge {
                    knowledgeContent
                        .transition(
                            .asymmetric(
                                insertion: .opacity.animation(.smooth(duration: 0.2).delay(0.3)),
                                removal: .opacity.animation(.smooth(duration: 0.15))
                            )
                        )
                } else if state == .browserSettings || state == .siteSettings {
                    SettingsPage(
                        type: state == .browserSettings ? .browser : .site,
                        currentURL: currentURL,
                        onDismiss: {
                            state = .collapsed
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.smooth(duration: 0.2).delay(0.3)),
                            removal: .opacity.animation(.smooth(duration: 0.15))
                        )
                    )
                } else {
                    searchSuggestionsArea
                        .opacity(suggestionsOpacity)
                        .allowsHitTesting(state == .search)
                        .frame(maxHeight: suggestionsExpanded ? .infinity : 0, alignment: .top)
                        .clipped()
                }

                if state != .search && state != .browserSettings && state != .siteSettings && state != .knowledge {
                    dragRevealedHistory
                }

                if state == .search || state == .collapsed || state == .hidden || state == .browserSettings || state == .siteSettings || state == .knowledge {
                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: state) { _, newState in
            let wasDragging = toolbarDragFraction > 0

            if newState == .search {
                suggestionsExpanded = true

                if wasDragging {
                    toolbarDragFraction = 0
                    var t = Transaction(animation: .none)
                    t.disablesAnimations = true
                    withTransaction(t) {
                        showHistory = true
                        suggestionsOpacity = 1
                    }
                } else {
                    toolbarDragFraction = 0
                    withAnimation(.smooth(duration: 0.15)) {
                        suggestionsOpacity = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.smooth(duration: 0.2)) {
                            showHistory = true
                        }
                    }
                }
            } else {
                isFocused = false
                toolbarDragFraction = 0

                withAnimation(.smooth(duration: 0.15)) {
                    showHistory = false
                    suggestionsOpacity = 0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if state != .search {
                        withAnimation(.smooth(duration: 0.2)) {
                            suggestionsExpanded = false
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    var searchBarRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                    .opacity(state == .search ? 1 : 0)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                    .opacity(state == .browserSettings ? 1 : 0)

                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                    .opacity(state == .knowledge ? 1 : 0)

                Button(action: onCopyUrl) {
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.8))
                }
                .opacity(state == .siteSettings ? 1 : 0)
                .allowsHitTesting(state == .siteSettings)
            }
            .frame(width: 44, height: 44)
            .matchedGeometryEffect(id: "magnifyingGlass_icon", in: animation, isSource: isExpanded)

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
            .focused($isFocused)
            .submitLabel(.go)
            .onSubmit(onSubmit)
            .frame(height: 44)
            .disabled(state == .siteSettings || state == .browserSettings || state == .knowledge)
            .truncationMode(
                (state == .siteSettings || state == .browserSettings || state == .knowledge) ? .tail : .head
            )

            Button(action: { text = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
            }
            .opacity(state == .search && !text.isEmpty ? 1 : 0)
            .allowsHitTesting(state == .search && !text.isEmpty)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            frostedBackground
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 1)
                )
                .matchedGeometryEffect(id: "searchBackground_fill", in: animation, isSource: isExpanded)
        )
        .overlay(alignment: .trailing) {
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .resizable()
                    .antialiased(true)
                    .scaledToFit()
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.8))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(reloadRotation), anchor: .center)
                    .drawingGroup()
                    .frame(width: 44, height: 44)
            }
            .opacity(state == .siteSettings ? 1 : 0)
            .allowsHitTesting(state == .siteSettings)
            .matchedGeometryEffect(id: "reloadButton", in: animation, isSource: isExpanded)
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
        .padding(.top, 16)
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
                                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
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
                                        .foregroundColor(AppTheme.Colors.text)
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
                                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(showHistory ? 1 : 0)
                        .blur(radius: showHistory ? 0 : 4)
                        .offset(y: showHistory ? 0 : 5)
                        .animation(
                            showHistory
                                ? .smooth(duration: 0.32).delay(Double(index) * 0.035)
                                : .smooth(duration: 0.07),
                            value: showHistory
                        )
                    }
                }
                .frame(minHeight: 10)
            }
        }
        .padding(.top, state == .search ? 0 : 12)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, (state == .search && isFocused) ? keyboardHeight : 0, for: .scrollContent)
    }

    @State private var keyboardHeight: CGFloat = 0

    private var dragRevealedHistory: some View {
        let historyOpacity = min(1.0, toolbarDragFraction * 3.0)

        return VStack(spacing: 0) {
            ForEach(
                Array(historyStore.recentEntries.enumerated()), id: \.element.id
            ) { _, entry in
                Button {
                    onHistoryTap(entry.url)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.text)
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
        .padding(.top, 12)
        .opacity(historyOpacity)
    }

    private var frostedBackground: some View {
        ZStack {
            AppTheme.Colors.uiElement
            AppTheme.Colors.background.opacity(0.1)
        }
    }

    private func triggerSpin() {
        guard isSpinning else { return }

        withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
            reloadRotation += 360
        }
    }

    var collapsedContent: some View {
        let dragFade = max(0, 1 - toolbarDragFraction * 3.0)
        let sideOpacity = isTabOverlayVisible ? 0.0 : dragFade
        let sideSlide: CGFloat = toolbarDragFraction * 14

        return HStack(spacing: 0) {
            Button(action: onTabsPressed) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.text.opacity(tabCount == 0 ? 0.35 : 1.0))
                        .frame(width: 44, height: 44)
                        .background(frostedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 1)
                        )
                }
            }
            .disabled(tabCount == 0)
            .padding(.leading, 8)
            .opacity(sideOpacity)
            .offset(x: -sideSlide)
            .animation(.smooth(duration: 0.2), value: isTabOverlayVisible)

            Spacer()

            Button(action: {
                if isTabOverlayVisible, let handler = onSearchPressedInTabOverlay {
                    handler()
                } else {
                    text = ""
                    withAnimation(.smooth(duration: 0.3)) {
                        state = .search
                    }
                }
            }) {
                ZStack {
                    frostedBackground
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "searchBackground_fill", in: animation, isSource: !isExpanded)
                        .frame(width: 80, height: 44)

                    HStack(spacing: 0) {
                        ZStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .matchedGeometryEffect(id: "magnifyingGlass_icon", in: animation, isSource: !isExpanded)

                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .frame(width: 18, height: 18)
                                .rotationEffect(.degrees(0))
                                .opacity(0)
                                .matchedGeometryEffect(id: "reloadButton", in: animation, isSource: !isExpanded)
                        }
                        .frame(width: 80, height: 44)

                        TextField("", text: .constant(""))
                            .labelsHidden()
                            .frame(width: 0, height: 0)
                            .opacity(0)
                    }
                }
            }

            Spacer()

            Button(action: onSettingsPressed) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.text)
                    .frame(width: 44, height: 44)
                    .background(frostedBackground)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.trailing, 8)
            .opacity(sideOpacity)
            .offset(x: sideSlide)
            .animation(.smooth(duration: 0.2), value: isTabOverlayVisible)
        }
        .frame(height: 80)
        .overlay(alignment: .topTrailing) {
            KnowledgeButton {
                withAnimation(.smooth(duration: 0.25)) {
                    state = .knowledge
                }
            }
            .padding(.trailing, 16)
            .alignmentGuide(.top) { d in d[.bottom] }
            .opacity(isTabOverlayVisible ? 0 : 1)
            .animation(.smooth(duration: 0.2), value: isTabOverlayVisible)
        }
    }

    private var knowledgeContent: some View {
        Spacer()
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
              let host = urlComponents.host else {
            return url.isEmpty ? "Search..." : url
        }

        var cleanHost = host
        if cleanHost.hasPrefix("www.") {
            cleanHost.removeFirst(4)
        }
        return cleanHost
    }
}
