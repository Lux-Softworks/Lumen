import SwiftUI
import UIKit

enum BottomBarState: Equatable {
    case hidden
    case collapsed
    case search
    case browserSettings
    case siteSettings
}

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

    var isExpanded: Bool { state != .collapsed }

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
                if state == .collapsed || state == .hidden {
                    // preserve drag here
                }
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
            }
        ) {
            VStack(spacing: 0) {
                if state == .search || state == .browserSettings || state == .siteSettings {
                    expandedContent
                        .transition(.opacity.animation(.smooth(duration: 0.3)))
                } else {
                    collapsedContent
                        .transition(.opacity.animation(.smooth(duration: 0.3)))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: state) { _, newState in
            if newState == .search || newState == .browserSettings || newState == .siteSettings {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation {
                        showHistory = true
                    }
                }
            } else {
                withAnimation {
                    showHistory = false
                }
                isFocused = false
            }
        }
    }

    var expandedContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if state == .siteSettings {
                    Button(action: onCopyUrl) {
                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.8))
                            .frame(width: 44, height: 44)
                    }
                    .matchedGeometryEffect(id: "magnifyingGlass", in: animation)
                } else {
                    Image(
                        systemName: state == .browserSettings ? "gearshape.fill" : "magnifyingglass"
                    )
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .matchedGeometryEffect(id: "magnifyingGlass", in: animation)
                }

                TextField(
                    state == .browserSettings ? "Browser Settings" : "Search...",
                    text: displayBinding
                )
                .font(.system(size: 17))
                .fontWeight(.bold)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.go)
                .onSubmit(onSubmit)
                .frame(height: 44)
                .disabled(state == .siteSettings || state == .browserSettings)
                .truncationMode(
                    (state == .siteSettings || state == .browserSettings) ? .tail : .head
                )
                .matchedGeometryEffect(id: "searchField", in: animation)

                if state == .search && !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.Colors.text.opacity(0.6))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if state == .siteSettings {
                    Button(action: onReload) {
                        ZStack {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 20, height: 20)

                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .antialiased(true)
                                .scaledToFit()
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text.opacity(0.8))
                                .frame(width: 18, height: 18)
                                .rotationEffect(.degrees(reloadRotation), anchor: .center)
                                .drawingGroup()
                        }
                        .frame(width: 44, height: 44)
                    }
                    .matchedGeometryEffect(id: "reloadButton", in: animation)
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
                    .matchedGeometryEffect(id: "searchBackground", in: animation)
            )
            .padding(.top, 16)

            if state == .search {
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
                                        ? .smooth(duration: 0.5).delay(0.05 + Double(index) * 0.04)
                                        : .smooth(duration: 0.15),
                                    value: showHistory
                                )
                            }
                        }
                        .frame(minHeight: 10)
                    }
                }
                .padding(.top, 12)
                .safeAreaPadding(.bottom, isFocused ? 320 : 0)
            }

            Spacer()
        }
        .opacity(state == .hidden ? 0 : 1)
        .padding(.bottom, state == .hidden ? -44 : 0)
        .animation(.smooth(duration: 0.3), value: state == .hidden)
    }

    private var frostedBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            AppTheme.Colors.uiElement.opacity(0.5)
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
        HStack(spacing: 0) {
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

            Spacer()

            Button(action: {
                text = ""
                withAnimation(.smooth(duration: 0.3)) {
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
                        .matchedGeometryEffect(id: "searchBackground", in: animation)
                        .frame(width: 80, height: 44)

                    HStack(spacing: 0) {
                        ZStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .matchedGeometryEffect(id: "magnifyingGlass", in: animation)

                            Image(systemName: "arrow.clockwise")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .frame(width: 18, height: 18)
                                .rotationEffect(.degrees(0))
                                .opacity(0)
                                .matchedGeometryEffect(id: "reloadButton", in: animation)
                        }
                        .frame(width: 80, height: 44)

                        TextField("", text: .constant(""))
                            .labelsHidden()
                            .frame(width: 0, height: 0)
                            .opacity(0)
                            .matchedGeometryEffect(id: "searchField", in: animation)
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
        }
        .frame(height: 80)
        .opacity((state == .collapsed || state == .hidden) ? 1 : 0)
        .animation(.smooth(duration: 0.3), value: state == .collapsed || state == .hidden)
    }

    private var displayBinding: Binding<String> {
        Binding(
            get: {
                if state == .browserSettings {
                    return "Browser Settings"
                } else if state == .siteSettings {
                    return neaten(url: currentURL?.absoluteString ?? text)
                } else {
                    return text
                }
            },
            set: {
                if state == .search {
                    text = $0
                }
            }
        )
    }

    private func neaten(url: String) -> String {
        var clean = url
        if clean.hasPrefix("https://") {
            clean.removeFirst(8)
        } else if clean.hasPrefix("http://") {
            clean.removeFirst(7)
        }
        if clean.hasPrefix("www.") { clean.removeFirst(4) }
        if clean.hasSuffix("/") { clean.removeLast() }
        return clean.isEmpty ? "Search..." : clean
    }
}

struct ResizableSheetContainer<Content: View>: View {
    @Binding var isExpanded: Bool
    @Binding var isCollapsed: Bool
    var isLoading: Bool
    var progress: Double
    var themeColor: UIColor?
    var onDragStart: (() -> Void)?
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onDismissFocused: (() -> Void)?
    let content: () -> Content

    @GestureState private var activeDragTranslation: CGFloat = 0
    @State private var releaseOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    private let expandedHeightRatio: CGFloat = 0.65
    private let collapsedHeight: CGFloat = 80
    private let sliverHeight: CGFloat = 20
    private let handleHeight: CGFloat = 60

    init(
        isExpanded: Binding<Bool>,
        isCollapsed: Binding<Bool>,
        isLoading: Bool,
        progress: Double,
        themeColor: UIColor? = nil,
        onDragStart: (() -> Void)? = nil,
        onExpand: (() -> Void)? = nil,
        onCollapse: (() -> Void)? = nil,
        onDismissFocused: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self._isCollapsed = isCollapsed
        self.isLoading = isLoading
        self.progress = progress
        self.themeColor = themeColor
        self.onDragStart = onDragStart
        self.onExpand = onExpand
        self.onCollapse = onCollapse
        self.onDismissFocused = onDismissFocused
        self.content = content
    }

    var body: some View {
        GeometryReader { outerGeometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.3)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isExpanded = false
                        }
                        onCollapse?()
                    }
                    .opacity(isExpanded ? 1 : 0)
                    .allowsHitTesting(isExpanded)
                    .zIndex(0)

                content()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .frame(
                        height: currentHeight(screenHeight: outerGeometry.size.height),
                        alignment: .top
                    )
                    .opacity(isCollapsed ? 0 : 1)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isCollapsed)
                    .background(
                        ZStack(alignment: .top) {
                            BlurView(style: .systemChromeMaterial)
                                .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                .overlay(
                                    Group {
                                        if colorScheme == .dark {
                                            Color.black.opacity(0.35)
                                        } else {
                                            Color.gray.opacity(0.1)
                                        }
                                    }
                                    .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                )
                                .cornerRadius(
                                    animatedCornerRadius(screenHeight: outerGeometry.size.height),
                                    corners: [.topLeft, .topRight]
                                )
                                .overlay(
                                    RoundedCorner(
                                        radius: animatedCornerRadius(
                                            screenHeight: outerGeometry.size.height),
                                        corners: [.topLeft, .topRight]
                                    )
                                    .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 0.5)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 15, y: -2)

                            ProgressView(
                                progress: progress,
                                isLoading: isLoading,
                                width: outerGeometry.size.width,
                                cornerRadius: animatedCornerRadius(
                                    screenHeight: outerGeometry.size.height),
                            )
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .updating($activeDragTranslation) { value, state, _ in
                                let translation = value.translation.height
                                let rubberBanded: CGFloat

                                if isExpanded {
                                    if translation > 0 {
                                        rubberBanded = translation
                                    } else {
                                        rubberBanded = 0
                                    }
                                } else {
                                    if translation < 0 {
                                        rubberBanded = translation
                                    } else {
                                        rubberBanded = translation * 0.1
                                    }
                                }
                                state = rubberBanded
                            }
                            .onChanged { value in
                                onDragStart?()

                                if abs(value.translation.height) > 10 {
                                    onDismissFocused?()
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                let velocity = value.velocity.height
                                let finalOffset: CGFloat

                                if isExpanded {
                                    if translation > 0 {
                                        finalOffset = translation
                                    } else {
                                        finalOffset = 0
                                    }
                                } else {
                                    if translation < 0 {
                                        finalOffset = translation
                                    } else {
                                        finalOffset = 0
                                    }
                                }

                                releaseOffset = finalOffset

                                let shouldExpand: Bool

                                if isExpanded {
                                    shouldExpand = translation < 100 && velocity < 500
                                } else {
                                    shouldExpand = translation < -50 || velocity < -500
                                }

                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isExpanded = shouldExpand
                                    releaseOffset = 0
                                }

                                if shouldExpand {
                                    onExpand?()
                                } else if isExpanded && !shouldExpand {
                                    onCollapse?()
                                }
                            }
                    )
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
        }
    }

    private var effectiveDrag: CGFloat {
        if activeDragTranslation != 0 {
            return activeDragTranslation
        }

        return releaseOffset
    }

    private func currentHeight(screenHeight: CGFloat) -> CGFloat {
        if isCollapsed {
            return sliverHeight
        }
        let baseHeight: CGFloat = isExpanded ? screenHeight * expandedHeightRatio : collapsedHeight
        let calculatedHeight = baseHeight - effectiveDrag

        return min(calculatedHeight, screenHeight * expandedHeightRatio)
    }

    private func animatedCornerRadius(screenHeight: CGFloat) -> CGFloat {
        let expandedRadius: CGFloat = 39
        let currentH = currentHeight(screenHeight: screenHeight)
        let expandedH = screenHeight * expandedHeightRatio
        let fraction = max(0, min(1, (currentH - collapsedHeight) / (expandedH - collapsedHeight)))

        return expandedRadius * fraction
    }
}

struct ProgressView: View {
    var progress: Double
    var isLoading: Bool
    var width: CGFloat
    var cornerRadius: CGFloat

    @State private var displayedProgress: Double = 0
    @State private var visible: Bool = false
    @State private var isFinishing: Bool = false

    private let gradient = LinearGradient(
        colors: [
            AppTheme.Colors.accent.opacity(0.5),
            AppTheme.Colors.accent.opacity(0.8),
            AppTheme.Colors.accent,
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(gradient)
                .blur(radius: 12)
                .opacity(0.25)
                .frame(height: 5.5)
                .shadow(
                    color: AppTheme.Colors.accent.opacity(0.25),
                    radius: 1, y: 10
                )

            Capsule()
                .fill(gradient)
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 1, y: 1
                )
                .frame(height: 1.3)
        }
        .scaleEffect(x: displayedProgress, anchor: .leading)
        .frame(maxWidth: width - cornerRadius * 2, maxHeight: .infinity, alignment: .topLeading)
        .opacity(visible ? 1 : 0)
        .offset(y: -2.2)
        .onChange(of: isLoading) { _, loading in
            if loading {
                isFinishing = false

                var transaction = Transaction(animation: .none)
                transaction.disablesAnimations = true

                withTransaction(transaction) {
                    displayedProgress = 0
                }

                withAnimation(.smooth(duration: 0.3)) {
                    visible = true
                }
            } else {
                isFinishing = true
                withAnimation(.smooth(duration: 0.3)) {
                    displayedProgress = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard self.isFinishing else { return }

                    withAnimation(.smooth(duration: 0.3)) {
                        visible = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard self.isFinishing else { return }

                        var transaction = Transaction(animation: .none)
                        transaction.disablesAnimations = true

                        withTransaction(transaction) {
                            displayedProgress = 0
                        }
                        isFinishing = false
                    }
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            guard !isFinishing else { return }

            if newValue > displayedProgress {
                withAnimation(.spring(response: 0.5, dampingFraction: 1.0)) {
                    displayedProgress = newValue
                }
            }
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )

        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
