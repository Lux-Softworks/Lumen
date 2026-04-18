import SwiftUI
import UIKit

struct TabOverlayView: View {
    @ObservedObject var tabManager: TabManager
    var hiddenTabId: UUID? = nil
    var shrinkProgress: CGFloat = 1
    var onSelectTab: (UUID) -> Void

    private let scale: CGFloat = 0.65
    private let toolbarHeight: CGFloat = 80

    @State private var lastScrolledToId: UUID? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var isDeletingTab: Bool = false

    var body: some View {
        GeometryReader { geo in
            let config = calculateLayout(in: geo)

            VStack(spacing: 0) {
                Color.clear.frame(height: config.headerHeight)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(tabManager.tabs, id: \.id) { tab in
                                TabCardWrapper(
                                    tab: tab,
                                    config: config,
                                    tabManager: tabManager,
                                    hiddenTabId: hiddenTabId,
                                    shrinkProgress: shrinkProgress,
                                    onSelectTab: onSelectTab,
                                    lastScrolledToId: $lastScrolledToId,
                                    isDeletingTab: $isDeletingTab
                                )
                            }
                        }
                        .padding(.horizontal, config.hPadding)
                    }
                    .coordinateSpace(name: "scrollView")
                    .scrollClipDisabled()
                    .scrollDisabled(isDeletingTab)
                    .frame(height: config.cardHeight)
                    .onAppear {
                        proxy.scrollTo(tabManager.activeTabId, anchor: .center)
                        lastScrolledToId = tabManager.activeTabId
                    }
                    .onChange(of: tabManager.activeTabId) { _, id in
                        guard id != lastScrolledToId else { return }
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                        lastScrolledToId = id
                    }
                    .onChange(of: tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId })) { _, _ in
                        withAnimation(.smooth(duration: 0.2)) {
                            proxy.scrollTo(tabManager.activeTabId, anchor: .center)
                        }
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
    @ObservedObject var tab: Tab
    let config: TabOverlayView.LayoutConfig
    @ObservedObject var tabManager: TabManager
    let hiddenTabId: UUID?
    let shrinkProgress: CGFloat
    let onSelectTab: (UUID) -> Void
    @Binding var lastScrolledToId: UUID?
    @Binding var isDeletingTab: Bool

    var body: some View {
        let hidden = tab.id == hiddenTabId

        GeometryReader { cardGeo in
            let cardFrame = cardGeo.frame(in: .named("scrollView"))
            let cardCenterX = cardFrame.midX
            let containerCenterX = config.safeWidth / 2

            let displacement = cardCenterX - containerCenterX

            let safeCardWidth = max(1.0, config.cardWidth)
            let normalizedDelta = displacement / safeCardWidth

            let cardScale: CGFloat = (
                normalizedDelta >= 0
                ? 1.0
                : max(0.90, 1.0 + (normalizedDelta * 0.03))
            )

            let targetVisualDisplacement: CGFloat = {
                if normalizedDelta >= 0 {
                    return normalizedDelta * safeCardWidth * 0.90
                } else {
                    let maxLeftLimit = safeCardWidth * 0.55
                    let stackCurve = 1.0 - exp(normalizedDelta * 1.2)
                    return -maxLeftLimit * stackCurve
                }
            }()

            let pushAmount: CGFloat = 20.0
            let rawProgress = (1.0 - shrinkProgress)
            let animationPush: CGFloat = {
                if rawProgress <= 0 || hidden { return 0 }
                if displacement < -10 {
                    return -pushAmount * rawProgress
                } else if displacement > 10 {
                    return pushAmount * rawProgress
                }
                return 0
            }()

            let xOffset = targetVisualDisplacement - displacement + animationPush

            let cardOpacity: CGFloat = {
                if hidden {
                    return 0
                } else if normalizedDelta >= -1.0 {
                    return 1.0
                } else {
                    let fadeDistance = abs(normalizedDelta) - 1.0
                    return max(0, 1.0 - (fadeDistance * 0.35))
                }
            }()

            let headerOpacity = max(0, 1.0 - abs(normalizedDelta) * 2.5)

            TabCardItemView(
                tab: tab,
                headerOpacity: headerOpacity,
                onClose: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        tabManager.closeTab(id: tab.id)
                    }
                },
                onTap: {
                    lastScrolledToId = tab.id
                    onSelectTab(tab.id)
                },
                isDeletingTab: $isDeletingTab
            )
            .frame(width: config.cardWidth, height: config.cardHeight)
            .scaleEffect(cardScale)
            .offset(x: xOffset)
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
    var headerOpacity: CGFloat = 1
    var onClose: () -> Void
    var onTap: () -> Void
    @Binding var isDeletingTab: Bool
    @Environment(\.palette) private var palette

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if tab.isIncognito {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(IncognitoPalette.accent)
                        .frame(width: 16, height: 16)
                } else {
                    let url = tab.viewModel.currentURL ?? tab.url
                    if let url, let faviconURL = FaviconService.faviconURL(for: url) {
                        AsyncImage(url: faviconURL) { img in
                            img.resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(palette.text.opacity(0.3))
                                .frame(width: 16, height: 16)
                        }
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundColor(palette.text.opacity(0.8))
                            .frame(width: 16, height: 16)
                    }
                }

                Text(tab.isIncognito
                     ? "Incognito · " + (tab.title.isEmpty ? "New Tab" : tab.title)
                     : (tab.title.isEmpty ? "New Tab" : tab.title))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tab.isIncognito ? IncognitoPalette.accent : palette.text)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .opacity(headerOpacity)

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
                        .foregroundColor(palette.text.opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.clear, lineWidth: 0)
            )
        }
        .offset(y: min(0, dragOffset))
        .overlay {
            VerticalSwipeDetector(
                onChanged: {
                    dragOffset = $0
                    if !isDeletingTab { isDeletingTab = true }
                },
                onEnded: { translation, velocity in
                    isDeletingTab = false
                    if translation < -60 || velocity < -400 {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                            dragOffset = -1000
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onClose() }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
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
