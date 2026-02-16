import SwiftUI
import UIKit

struct BottomBarView: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    @Binding var isCollapsed: Bool
    @FocusState.Binding var isFocused: Bool
    var isLoading: Bool
    var progress: Double

    var onTabsPressed: () -> Void
    var onSettingsPressed: () -> Void
    var onSubmit: () -> Void

    @Namespace private var animation

    var body: some View {
        ResizableSheetContainer(
            isExpanded: $isExpanded,
            isCollapsed: $isCollapsed,
            isLoading: isLoading,
            progress: progress,
            onDragStart: {
                if isCollapsed {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                        isCollapsed = false
                    }
                }
                isFocused = false
            }
        ) {
            VStack(spacing: 0) {
                if isExpanded {
                    expandedContent
                        .transition(.opacity.animation(.easeInOut(duration: 0.1)))
                } else {
                    collapsedContent
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: isExpanded) { expanded in
            if !expanded {
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
                    .fontWeight(.medium)
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
    var onDragStart: (() -> Void)?
    let content: () -> Content

    @GestureState private var activeDragTranslation: CGFloat = 0
    @State private var releaseOffset: CGFloat = 0

    private let expandedHeightRatio: CGFloat = 0.65
    private let collapsedHeight: CGFloat = 80
    private let sliverHeight: CGFloat = 20
    private let handleHeight: CGFloat = 60

    init(
        isExpanded: Binding<Bool>,
        isCollapsed: Binding<Bool>,
        isLoading: Bool,
        progress: Double,
        onDragStart: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self._isCollapsed = isCollapsed
        self.isLoading = isLoading
        self.progress = progress
        self.onDragStart = onDragStart
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                        isExpanded = false
                    }
                }
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)
                .zIndex(0)

            content()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .frame(
                    height: currentHeight,
                    alignment: .top
                )
                .opacity(isCollapsed ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: isCollapsed)
                .background(
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(.ultraThickMaterial)
                            .opacity(0.975)
                            .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                            .cornerRadius(animatedCornerRadius, corners: [.topLeft, .topRight])
                            .shadow(color: Color.black.opacity(0.15), radius: 10, y: -5)

                        if isLoading || progress > 0 && progress < 1.0 {
                            PlasmaProgressView(progress: progress)
                                .frame(height: 3)
                                .cornerRadius(animatedCornerRadius, corners: [.topLeft, .topRight])
                        }
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
                        .onChanged { _ in
                            onDragStart?()
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
                                .spring(response: 0.35, dampingFraction: 1.0, blendDuration: 0.1)
                            ) {
                                isExpanded = shouldExpand
                                releaseOffset = 0
                            }
                        }
                )
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
    }

    private var effectiveDrag: CGFloat {
        if activeDragTranslation != 0 {
            return activeDragTranslation
        }

        return releaseOffset
    }

    private var currentHeight: CGFloat {
        if isCollapsed {
            return sliverHeight
        }
        let screenHeight = UIScreen.main.bounds.height
        let baseHeight: CGFloat = isExpanded ? screenHeight * expandedHeightRatio : collapsedHeight
        return baseHeight - effectiveDrag
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

    @State private var displayedProgress: Double = 0
    @State private var animateGradient = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.secondary.opacity(0.1)

                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.2),
                        Color(red: 1.0, green: 0.65, blue: 0.1),
                        Color(red: 0.9, green: 0.3, blue: 0.4),
                        Color(red: 0.6, green: 0.1, blue: 0.6),
                        Color(red: 0.2, green: 0.0, blue: 0.6),
                    ],
                    startPoint: animateGradient ? .leading : .trailing,
                    endPoint: animateGradient ? .trailing : .leading
                )
                .animation(
                    .linear(duration: 2.0).repeatForever(autoreverses: false),
                    value: animateGradient
                )
                .mask(
                    Rectangle()
                        .frame(width: geometry.size.width * CGFloat(displayedProgress))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 1.0, blendDuration: 0.1),
                            value: displayedProgress
                        )
                )
            }
            .onAppear {
                animateGradient = true
                displayedProgress = progress
            }
            .onChange(of: progress) { newValue in
                if newValue > displayedProgress {
                    displayedProgress = newValue
                }
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
