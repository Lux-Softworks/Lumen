import SwiftUI
import UIKit

struct BottomBarView: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    @Binding var isCollapsed: Bool
    @FocusState.Binding var isFocused: Bool
    var isLoading: Bool
    var progress: Double

    var searchSuggestions: [SearchSuggestion] = []
    var themeColor: UIColor?

    var onTabsPressed: () -> Void
    var onSettingsPressed: () -> Void
    var onSubmit: () -> Void
    var onHistoryTap: (String) -> Void

    @ObservedObject private var historyStore = HistoryStore.shared
    @Namespace private var animation
    @State private var showHistory = false

    var body: some View {
        ResizableSheetContainer(
            isExpanded: $isExpanded,
            isCollapsed: $isCollapsed,
            isLoading: isLoading,
            progress: progress,
            themeColor: themeColor,
            onDragStart: {
                if isCollapsed {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                        isCollapsed = false
                    }
                }
            },
            onExpand: {
                isFocused = true
            },
            onCollapse: {
                isFocused = false
            },
            onDismissFocused: {
                isFocused = false
            }
        ) {
            VStack(spacing: 0) {
                if isExpanded {
                    expandedContent
                        .transition(.opacity.animation(.smooth(duration: 0.15)))
                } else {
                    collapsedContent
                        .transition(.opacity.animation(.smooth(duration: 0.15)))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
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
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "magnifyingGlass", in: animation)

                TextField("Search...", text: $text)
                    .font(.system(size: 17))
                    .fontWeight(.bold)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
                    .frame(height: 44)
                    .matchedGeometryEffect(id: "searchField", in: animation)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                Color.primary.opacity(0.08)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .matchedGeometryEffect(id: "searchBackground", in: animation)
            )
            .padding(.top, 16)

            if !searchSuggestions.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
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
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        let attributedText: AttributedString = {
                                            var attributedText = AttributedString(suggestion.text)

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
                                                        attributedText[attrRange].font = .system(
                                                            size: 16, weight: .bold)
                                                        attributedText[attrRange].foregroundColor =
                                                            .primary
                                                    }
                                                    searchRange =
                                                        range.upperBound..<suggestion.text.endIndex
                                                }
                                            }

                                            return attributedText
                                        }()

                                        Text(attributedText)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
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
                .padding(.top, 12)
                .safeAreaPadding(.bottom, isFocused ? 320 : 0)
            } else if !historyStore.recentEntries.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(historyStore.recentEntries.enumerated()), id: \.element.id) {
                            index, entry in
                            Button {
                                onHistoryTap(entry.url)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
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
                .padding(.top, 12)
                .safeAreaPadding(.bottom, isFocused ? 320 : 0)
            }

            Spacer()
        }
        .opacity(isCollapsed ? 0 : 1)
        .padding(.bottom, isCollapsed ? -44 : 0)
        .animation(.easeInOut(duration: 0.15), value: isCollapsed)
    }

    var collapsedContent: some View {
        HStack(spacing: 0) {
            Button(action: onTabsPressed) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.leading, 8)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }
            }) {
                ZStack {
                    Color.primary.opacity(0.08)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "searchBackground", in: animation)
                        .frame(width: 80, height: 44)

                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.primary.opacity(0.9))
                            .matchedGeometryEffect(id: "magnifyingGlass", in: animation)

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
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.trailing, 8)
        }
        .frame(height: 80)
        .opacity(isCollapsed ? 0 : 1)
        .animation(.easeInOut(duration: 0.15), value: isCollapsed)
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
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
                    .animation(.easeInOut(duration: 0.2), value: isCollapsed)
                    .background(
                        ZStack(alignment: .top) {
                            BlurView(style: .systemChromeMaterial)
                                .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                .overlay(
                                    Group {
                                        if let themeColor = themeColor {
                                            Color(themeColor).opacity(0.7)
                                        } else if colorScheme == .dark {
                                            Color.black.opacity(0.35)
                                        } else {
                                            Color.gray.opacity(0.1)
                                        }
                                    }
                                    .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                )
                                .cornerRadius(animatedCornerRadius, corners: [.topLeft, .topRight])
                                .overlay(
                                    RoundedCorner(
                                        radius: animatedCornerRadius,
                                        corners: [.topLeft, .topRight]
                                    )
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 15, y: -2)

                            PlasmaProgressView(progress: progress, isLoading: isLoading)
                                .frame(height: 1.4)
                                .cornerRadius(
                                    animatedCornerRadius, corners: [.topLeft, .topRight]
                                )
                                .opacity(isExpanded ? 0 : 1)
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

                                withAnimation(
                                    .spring(
                                        response: 0.35, dampingFraction: 0.8, blendDuration: 0.1)
                                ) {
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

    private var animatedCornerRadius: CGFloat {
        let dragInfo = effectiveDrag

        if isExpanded {
            return 30 * (1 - max(0, min(1, dragInfo / 400)))
        } else {
            return 30 * (max(0, min(1, abs(dragInfo) / 100)))
        }
    }
}

struct PlasmaProgressView: View {
    var progress: Double
    var isLoading: Bool

    @State private var displayedProgress: Double = 0
    @State private var visible: Bool = false

    @State private var isFinishing: Bool = false

    private let gradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.85, blue: 0.1),
            Color(red: 1.0, green: 0.55, blue: 0.1),
            Color(red: 0.9, green: 0.25, blue: 0.4),
            Color(red: 0.55, green: 0.1, blue: 0.65),
            Color(red: 0.25, green: 0.05, blue: 0.7),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                gradient
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width * CGFloat(displayedProgress))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
            }
            .opacity(visible ? 1 : 0)
        }
        .onChange(of: isLoading) { _, loading in
            if loading {
                isFinishing = false

                withAnimation(.smooth(duration: 0.2)) {
                    visible = true
                }
            } else {
                isFinishing = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    guard self.isFinishing else { return }

                    withAnimation(.smooth(duration: 0.3)) {
                        visible = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        guard self.isFinishing else { return }
                        displayedProgress = 0
                        isFinishing = false
                    }
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            guard !isFinishing else { return }
            guard visible else { return }

            if newValue > displayedProgress {
                displayedProgress = newValue
            }
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

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
