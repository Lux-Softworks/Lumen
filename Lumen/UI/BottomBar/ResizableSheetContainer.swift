import SwiftUI
import UIKit

struct ResizableSheetContainer<Content: View>: View {
    @Binding var isExpanded: Bool
    @Binding var isCollapsed: Bool
    var isLoading: Bool
    var progress: Double
    var expandedHeightRatio: CGFloat
    var themeColor: UIColor?
    var backdropOpacity: CGFloat
    var onDragStart: (() -> Void)?
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onDismissFocused: (() -> Void)?
    var onDragProgress: ((CGFloat) -> Void)?
    let content: () -> Content

    @GestureState private var activeDragTranslation: CGFloat = 0
    @State private var releaseOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.palette) var palette

    private let collapsedHeight: CGFloat = 80
    private let sliverHeight: CGFloat = 20
    private let handleHeight: CGFloat = 60

    init(
        isExpanded: Binding<Bool>,
        isCollapsed: Binding<Bool>,
        isLoading: Bool,
        progress: Double,
        expandedHeightRatio: CGFloat = 0.65,
        themeColor: UIColor? = nil,
        backdropOpacity: CGFloat = 1,
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
        self.expandedHeightRatio = expandedHeightRatio
        self.themeColor = themeColor
        self.backdropOpacity = backdropOpacity
        self.onDragStart = onDragStart
        self.onExpand = onExpand
        self.onCollapse = onCollapse
        self.onDismissFocused = onDismissFocused
        self.onDragProgress = onDragProgress
        self.content = content
    }

    var body: some View {
        GeometryReader { outerGeometry in
            let screenHeight = outerGeometry.size.height
            let sheetHeight = currentHeight(screenHeight: screenHeight)
            let cornerR = animatedCornerRadius(screenHeight: screenHeight)

            ZStack(alignment: .bottom) {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(AppTheme.Motion.sheet) {
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
                    .frame(height: sheetHeight, alignment: .top)
                    .opacity(isCollapsed ? 0 : 1)
                    .background(
                        ZStack(alignment: .top) {
                            Rectangle()
                                .fill(.regularMaterial)
                                .environment(\.colorScheme, palette.isIncognito ? .dark : colorScheme)
                                .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                .overlay(
                                    Group {
                                        if palette.isIncognito {
                                            palette.background.opacity(0.85)
                                        } else if colorScheme == .dark {
                                            Color.black.opacity(0.28)
                                        } else {
                                            Color.white.opacity(0.22)
                                        }
                                    }
                                    .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                )
                                .cornerRadius(cornerR, corners: [.topLeft, .topRight])
                                .overlay(
                                    RoundedCorner(radius: cornerR, corners: [.topLeft, .topRight])
                                        .stroke(palette.text.opacity(0.15), lineWidth: 0.5)
                                )
                                .shadow(color: Color.black.opacity(0.18), radius: 6, y: -1)
                                .opacity(backdropOpacity)

                            ProgressView(
                                progress: progress,
                                isLoading: isLoading,
                                width: outerGeometry.size.width,
                                cornerRadius: cornerR,
                            )
                        }
                    )
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
                            .updating($activeDragTranslation) { value, state, _ in
                                state = value.translation.height

                                let screenH = outerGeometry.size.height
                                guard screenH > 0 else { return }
                                let expandedH = screenH * expandedHeightRatio

                                if !isExpanded {
                                    let upDrag = max(0, -value.translation.height)
                                    let resistedHeight = logarithmicResistance(upDrag)
                                    let totalTravel = expandedH - collapsedHeight
                                    if totalTravel > 0 {
                                        let progress = resistedHeight / totalTravel
                                        onDragProgress?(max(0, min(progress, 1)))
                                    }
                                } else {
                                    let downDrag = max(0, value.translation.height)
                                    let totalTravel = expandedH - collapsedHeight
                                    if totalTravel > 0 {
                                        let progress = 1 - min(1, downDrag / totalTravel)
                                        onDragProgress?(max(0, progress))
                                    }
                                }
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

                                withAnimation(AppTheme.Motion.sheet) {
                                    isExpanded = shouldExpand
                                    releaseOffset = 0
                                }

                                if shouldExpand {
                                    onExpand?()
                                } else if !shouldExpand {
                                    onCollapse?()
                                }
                            }
                    )
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
            .haptic(.snap, trigger: isExpanded)
            .haptic(.soft, trigger: isCollapsed)
        }
    }

    private var effectiveDrag: CGFloat {
        if activeDragTranslation != 0 {
            return activeDragTranslation
        }

        return releaseOffset
    }

    private func logarithmicResistance(_ raw: CGFloat) -> CGFloat {
        guard raw > 0 else { return 0 }
        let k: CGFloat = 600
        return k * (1 - exp(-raw / k))
    }

    private func currentHeight(screenHeight: CGFloat) -> CGFloat {
        if isCollapsed { return sliverHeight }

        let expandedH = screenHeight * expandedHeightRatio
        let drag = effectiveDrag

        if isExpanded {
            if drag < 0 {
                return expandedH + logarithmicResistance(-drag)
            }
            return max(expandedH - drag, sliverHeight)
        } else {
            if drag < 0 {
                return min(collapsedHeight + logarithmicResistance(-drag), expandedH)
            }
            return max(collapsedHeight - logarithmicResistance(drag) * 0.35, sliverHeight)
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
