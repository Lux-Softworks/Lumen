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

    var onTabsPressed: () -> Void
    var onSettingsPressed: () -> Void
    var onSubmit: () -> Void
    var onHistoryTap: (String) -> Void

    var onCopyUrl: () -> Void
    var onReload: () -> Void

    @ObservedObject private var historyStore = HistoryStore.shared

    @Namespace private var animation
    @State private var showHistory = false
    @State private var reloadRotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var toolbarDragFraction: CGFloat = 0
    @State private var suggestionsExpanded = false
    @State private var suggestionsOpacity: Double = 0

    var isExpanded: Bool { state != .collapsed }
    var showSearchBar: Bool { state == .search || state == .browserSettings || state == .siteSettings }

    var body: some View {
        ResizableSheetContainer(
            isExpanded: Binding(
                get: { state == .search || state == .browserSettings || state == .siteSettings },
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
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
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
                        .opacity(showSearchBar ? 0 : 1)
                        .allowsHitTesting(!showSearchBar)

                    searchBarRow
                        .opacity(showSearchBar ? 1 : 0)
                        .allowsHitTesting(showSearchBar)
                }

                if state == .browserSettings || state == .siteSettings {
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
                        .safeAreaPadding(.bottom, (state == .search && isFocused) ? keyboardHeight : 0)
                }

                if state != .search && state != .browserSettings && state != .siteSettings {
                    dragRevealedHistory
                }

                if state == .search || state == .collapsed || state == .hidden || state == .browserSettings || state == .siteSettings {
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
                keyboardHeight = frame.height - 10
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

                Button(action: onCopyUrl) {
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.8))
                }
                .opacity(state == .siteSettings ? 1 : 0)
                .allowsHitTesting(state == .siteSettings)
            }
            .frame(width: 44, height: 44)
            .matchedGeometryEffect(id: "magnifyingGlass", in: animation, isSource: showSearchBar)

            TextField(
                state == .browserSettings ? "Browser Settings" : "Search...",
                text: displayBinding
            )
            .font(
                (state == .browserSettings || state == .siteSettings)
                    ? AppTheme.Typography.serifDisplay(size: 17, weight: .bold)
                    : AppTheme.Typography.sansBody(size: 17, weight: .bold)
            )
            .textFieldStyle(.plain)
            .focused($isFocused)
            .submitLabel(.go)
            .onSubmit(onSubmit)
            .frame(height: 44)
            .disabled(state == .siteSettings || state == .browserSettings)
            .truncationMode(
                (state == .siteSettings || state == .browserSettings) ? .tail : .head
            )
            .matchedGeometryEffect(id: "searchField", in: animation, isSource: showSearchBar)

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
                .matchedGeometryEffect(id: "searchBackground", in: animation, isSource: showSearchBar)
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
            .matchedGeometryEffect(id: "reloadButton", in: animation, isSource: showSearchBar)
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
                            text = suggestion.text
                            onSubmit()
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
        .padding(.top, 12)
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

    // TODO: make this smooth at one point but one rotation is good enough for now
    private func triggerSpin() {
        guard isSpinning else { return }

        withAnimation(.interpolatingSpring(stiffness: 100, damping: 10)) {
            reloadRotation += 360
        }
    }

    var collapsedContent: some View {
        let sideOpacity = max(0, 1 - toolbarDragFraction * 3.0)
        let sideSlide: CGFloat = toolbarDragFraction * 14

        return HStack(spacing: 0) {
            Button(action: onTabsPressed) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.text)
                    .frame(width: 44, height: 44)
                    .background(frostedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.leading, 8)
            .opacity(sideOpacity)
            .offset(x: -sideSlide)

            Spacer()

            Button(action: {
                text = ""
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    state = .search
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }) {
                ZStack {
                    frostedBackground
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "searchBackground", in: animation, isSource: !showSearchBar)
                        .frame(width: 80, height: 44)

                    HStack(spacing: 0) {
                        ZStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .matchedGeometryEffect(id: "magnifyingGlass", in: animation, isSource: !showSearchBar)

                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .frame(width: 18, height: 18)
                                .rotationEffect(.degrees(0))
                                .opacity(0)
                                .matchedGeometryEffect(id: "reloadButton", in: animation, isSource: !showSearchBar)
                        }
                        .frame(width: 80, height: 44)

                        TextField("", text: .constant(""))
                            .labelsHidden()
                            .frame(width: 0, height: 0)
                            .opacity(0)
                            .matchedGeometryEffect(id: "searchField", in: animation, isSource: !showSearchBar)
                    }
                }
            }

            Spacer()

            Button(action: onSettingsPressed) {
                Image(systemName: "chevron.up")
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
        }
        .frame(height: 80)
    }

    private var displayBinding: Binding<String> {
        Binding(
            get: {
                switch state {
                case .browserSettings:
                    return "Browser Settings"
                case .siteSettings:
                    return neaten(url: currentURL?.absoluteString ?? text)
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
