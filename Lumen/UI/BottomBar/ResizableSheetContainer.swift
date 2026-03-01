import SwiftUI
import UIKit

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
    var onDragProgress: ((CGFloat) -> Void)?
    let content: () -> Content

    @GestureState private var activeDragTranslation: CGFloat = 0
    @State private var releaseOffset: CGFloat = 0
    @State private var cachedScreenHeight: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    private let expandedHeightRatio: CGFloat = 0.65
    private let collapsedHeight: CGFloat = 80
    private let sliverHeight: CGFloat = 20

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
        onDragProgress: ((CGFloat) -> Void)? = nil,
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
        self.onDragProgress = onDragProgress
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
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
                        height: currentHeight(screenHeight: geometry.size.height),
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
                                    animatedCornerRadius(screenHeight: geometry.size.height),
                                    corners: [.topLeft, .topRight]
                                )
                                .overlay(
                                    RoundedCorner(
                                        radius: animatedCornerRadius(
                                            screenHeight: geometry.size.height),
                                        corners: [.topLeft, .topRight]
                                    )
                                    .stroke(AppTheme.Colors.text.opacity(0.15), lineWidth: 0.5)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 15, y: -2)

                            ProgressView(
                                progress: progress,
                                isLoading: isLoading,
                                width: geometry.size.width,
                                cornerRadius: animatedCornerRadius(
                                    screenHeight: geometry.size.height),
                            )
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .updating($activeDragTranslation) { value, state, _ in
                                state = value.translation.height
                            }
                            .onChanged { value in
                                onDragStart?()

                                if abs(value.translation.height) > 10 {
                                    onDismissFocused?()
                                }

                                if !isExpanded && !isCollapsed && geometry.size.height > 0 {
                                    let upDrag = max(0, -value.translation.height)
                                    let resistedHeight = logarithmicResistance(upDrag)
                                    let totalTravel =
                                        geometry.size.height * expandedHeightRatio - collapsedHeight
                                    let fraction = min(1.0, resistedHeight / totalTravel)
                                    onDragProgress?(fraction)
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation.height
                                let velocity = value.velocity.height

                                let finalOffset: CGFloat
                                if isExpanded {
                                    finalOffset = translation > 0 ? translation : 0
                                } else {
                                    finalOffset = translation < 0 ? translation : 0
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

                                if !shouldExpand {
                                    onDragProgress?(0)
                                }
                            }
                    )
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
            .onAppear { cachedScreenHeight = geometry.size.height }
            .onChange(of: geometry.size.height) { _, h in cachedScreenHeight = h }
        }
    }

    private var effectiveDrag: CGFloat {
        activeDragTranslation != 0 ? activeDragTranslation : releaseOffset
    }

    private func logarithmicResistance(_ raw: CGFloat) -> CGFloat {
        guard raw > 0 else { return 0 }
        let k: CGFloat = 600
        return k * (1 - exp(-raw / k))
    }

    private func currentHeight(screenHeight: CGFloat) -> CGFloat {
        if isCollapsed { return sliverHeight }

        let expandedH = screenHeight * expandedHeightRatio

        if isExpanded {
            if effectiveDrag < 0 {
                return expandedH + logarithmicResistance(-effectiveDrag)
            }
            return max(expandedH - effectiveDrag, sliverHeight)
        } else {
            if effectiveDrag < 0 {
                return min(collapsedHeight + logarithmicResistance(-effectiveDrag), expandedH)
            }
            return max(collapsedHeight - effectiveDrag * 0.1, sliverHeight)
        }
    }

    private func animatedCornerRadius(screenHeight: CGFloat) -> CGFloat {
        let expandedRadius: CGFloat = 39
        let currentH = currentHeight(screenHeight: screenHeight)
        let expandedH = screenHeight * expandedHeightRatio
        let fraction = max(0, min(1, (currentH - collapsedHeight) / (expandedH - collapsedHeight)))
        return expandedRadius * fraction
    }
}
