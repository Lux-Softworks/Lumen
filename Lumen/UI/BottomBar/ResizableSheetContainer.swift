import SwiftUI
import UIKit

struct ResizableSheetContainer<Content: View>: View {
    @Binding var isExpanded: Bool
    @Binding var isCollapsed: Bool
    var isLoading: Bool
    var progress: Double
    var expandedHeightRatio: CGFloat
    var themeColor: UIColor?
    var onDragStart: (() -> Void)?
    var onExpand: (() -> Void)?
    var onCollapse: (() -> Void)?
    var onDismissFocused: (() -> Void)?
    var onDragProgress: ((CGFloat) -> Void)?
    let content: () -> Content

    @GestureState private var activeDragTranslation: CGFloat = 0
    @State private var releaseOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

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
        self.onDragStart = onDragStart
        self.onExpand = onExpand
        self.onCollapse = onCollapse
        self.onDismissFocused = onDismissFocused
        self.onDragProgress = onDragProgress
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
                        withAnimation(.smooth(duration: 0.3)) {
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
                    .animation(.smooth(duration: 0.3), value: isExpanded)
                    .opacity(isCollapsed ? 0 : 1)
                    .background(
                        ZStack(alignment: .top) {
                            BlurView(style: .systemChromeMaterial)
                                .ignoresSafeArea(.all, edges: isExpanded ? .all : .bottom)
                                .overlay(
                                    Group {
                                        if colorScheme == .dark {
                                            ZStack {
                                                Color.black.opacity(0.4)
                                            }
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
                        DragGesture(minimumDistance: 10, coordinateSpace: .global)
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

                                let screenHeight = outerGeometry.size.height
                                let currentHeight =
                                    isExpanded
                                    ? screenHeight * expandedHeightRatio : collapsedHeight
                                let targetHeight =
                                    isExpanded
                                    ? collapsedHeight : screenHeight * expandedHeightRatio
                                let diff = abs(targetHeight - currentHeight)
                                if diff > 0 {
                                    let progress = abs(rubberBanded) / diff
                                    onDragProgress?(max(0, min(progress, 1)))
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

                                withAnimation(.smooth(duration: 0.3)) {
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
