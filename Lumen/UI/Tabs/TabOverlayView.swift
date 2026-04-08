import SwiftUI
import UIKit

struct TabOverlayView: View {
    @ObservedObject var tabManager: TabManager
    var hiddenTabId: UUID? = nil
    var shrinkProgress: CGFloat = 1
    var onSelectTab: (UUID) -> Void

    private let scale: CGFloat = 0.72
    private let toolbarHeight: CGFloat = 80

    private let kShrink: CGFloat = 0.15
    private let sMin: CGFloat = 0.75
    private let baseSpacing: CGFloat = 80
    private let overlapCompensation: CGFloat = 40
    private let wideSpacing: CGFloat = 320
    private let kDepth: CGFloat = 20

    @State private var lastScrolledToId: UUID? = nil
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let config = calculateLayout(in: geo)

            VStack(spacing: 0) {
                Color.clear.frame(height: config.headerHeight)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                                TabCardWrapper(
                                    index: index,
                                    tab: tab,
                                    config: config,
                                    tabManager: tabManager,
                                    hiddenTabId: hiddenTabId,
                                    kShrink: kShrink,
                                    sMin: sMin,
                                    baseSpacing: baseSpacing,
                                    overlapCompensation: overlapCompensation,
                                    wideSpacing: wideSpacing,
                                    kDepth: kDepth,
                                    onSelectTab: onSelectTab,
                                    lastScrolledToId: $lastScrolledToId
                                )
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, config.hPadding)
                    }
                    .coordinateSpace(name: "scrollView")
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                    .frame(height: config.cardHeight)
                    .onAppear {
                        proxy.scrollTo(tabManager.activeTabId, anchor: .center)
                        lastScrolledToId = tabManager.activeTabId
                    }
                    .onChange(of: tabManager.activeTabId) { _, id in
                        guard id != lastScrolledToId else { return }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                        lastScrolledToId = id
                    }
                }

                Color.clear.frame(height: toolbarHeight)
            }
        }
    }

    internal struct LayoutConfig {
        let safeWidth: CGFloat
        let safeHeight: CGFloat
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let headerHeight: CGFloat
        let hPadding: CGFloat
    }

    private func calculateLayout(in geo: GeometryProxy) -> LayoutConfig {
        let safeWidth = safe(geo.size.width)
        let safeHeight = safe(geo.size.height)
        let toolbarYPosition = safe(safeHeight - toolbarHeight)
        let desiredCardWidth = safe(safeWidth * scale)
        let desiredCardHeight = safe(safeHeight * scale)
        let maxCardHeight = safe(toolbarYPosition)
        let cardHeight = safe(min(desiredCardHeight, maxCardHeight))
        let cardWidth = safe(min(desiredCardWidth, safeWidth))
        let headerHeight = safe((toolbarYPosition - cardHeight) / 2)
        let hPadding = safe((safeWidth - cardWidth) / 2)

        return LayoutConfig(
            safeWidth: safeWidth,
            safeHeight: safeHeight,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            headerHeight: headerHeight,
            hPadding: hPadding
        )
    }

    private func safe(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }
}

private struct TabCardWrapper: View {
    let index: Int
    @ObservedObject var tab: Tab
    let config: TabOverlayView.LayoutConfig
    @ObservedObject var tabManager: TabManager
    let hiddenTabId: UUID?
    let kShrink: CGFloat
    let sMin: CGFloat
    let baseSpacing: CGFloat
    let overlapCompensation: CGFloat
    let wideSpacing: CGFloat
    let kDepth: CGFloat
    let onSelectTab: (UUID) -> Void
    @Binding var lastScrolledToId: UUID?

    var body: some View {
        let hidden = tab.id == hiddenTabId

        GeometryReader { cardGeo in
            let cardFrame = cardGeo.frame(in: .named("scrollView"))
            let cardCenterX = cardFrame.midX
            let containerCenterX = config.hPadding + (config.safeWidth - 2 * config.hPadding) / 2

            let displacement = cardCenterX - containerCenterX
            let normalizedDelta = displacement / config.cardWidth

            let delta = normalizedDelta
            let absDelta = abs(delta)

            let cardScale: CGFloat = max(1.0 - (absDelta * kShrink), sMin)

            let xOffset: CGFloat = (
                delta < 0
                ? (delta * baseSpacing) + ((1.0 - cardScale) * overlapCompensation * config.cardWidth)
                : delta * wideSpacing
            )

            let cardOpacity = hidden ? 0 : max(1.0 - (absDelta * 0.3), 0)

            let zDepth = -absDelta * kDepth

            TabCardItemView(
                tab: tab,
                onClose: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        tabManager.closeTab(id: tab.id)
                    }
                },
                onTap: {
                    lastScrolledToId = tab.id
                    onSelectTab(tab.id)
                }
            )
            .frame(width: config.cardWidth, height: config.cardHeight)
            .scaleEffect(cardScale)
            .offset(x: xOffset)
            .zIndex(Double(index) + zDepth)
            .opacity(cardOpacity)
            .allowsHitTesting(!hidden)
        }
        .frame(width: config.cardWidth, height: config.cardHeight)
        .id(tab.id)
    }
}

private struct VerticalSwipeDetector: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: VerticalSwipeDetector

        init(_ parent: VerticalSwipeDetector) {
            self.parent = parent
        }

        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            guard let pan = gr as? UIPanGestureRecognizer, let view = pan.view else { return false }
            let vel = pan.velocity(in: view)
            return vel.y < 0 && abs(vel.y) > abs(vel.x) * 1.5
        }

        func gestureRecognizer(
            _ gr: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        @objc func handle(_ pan: UIPanGestureRecognizer) {
            guard let view = pan.view else { return }
            switch pan.state {
            case .changed:
                parent.onChanged(pan.translation(in: view).y)
            case .ended, .cancelled:
                parent.onEnded(
                    pan.translation(in: view).y,
                    pan.velocity(in: view).y
                )
            default: break
            }
        }
    }
}

private struct TabCardItemView: View {
    @ObservedObject var tab: Tab
    var onClose: () -> Void
    var onTap: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                let url = tab.viewModel.currentURL ?? tab.url
                if let url, let faviconURL = FaviconService.faviconURL(for: url) {
                    AsyncImage(url: faviconURL) { img in
                        img.resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 16, height: 16)
                }

                Text(tab.title.isEmpty ? "New Tab" : tab.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)

            ZStack {
                if let snapshot = tab.snapshot {
                    Image(uiImage: snapshot)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Color(white: 0.10)
                    Image(systemName: "globe")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundColor(.white.opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .offset(y: min(0, dragOffset))
        .opacity(dragOffset < 0 ? Double(max(0.0, 1 + dragOffset / 160)) : 1)
        .overlay {
            VerticalSwipeDetector(
                onChanged: { dragOffset = $0 },
                onEnded: { translation, velocity in
                    if translation < -80 || velocity < -600 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = -500
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onClose() }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
