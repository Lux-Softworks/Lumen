import SwiftUI
import UIKit

struct TabOverlayView: View {
    @ObservedObject var tabManager: TabManager
    var hiddenTabId: UUID? = nil
    var shrinkProgress: CGFloat = 1
    var onSelectTab: (UUID) -> Void

    private let scale: CGFloat = 0.72
    private let toolbarHeight: CGFloat = 80
    
    @State private var lastScrolledToId: UUID? = nil

    var body: some View {
        GeometryReader { geo in
            let safeWidth = safe(geo.size.width)
            let safeHeight = safe(geo.size.height)

            let toolbarYPosition = safe(safeHeight - toolbarHeight)

            let desiredCardWidth = safe(safeWidth * scale)
            let desiredCardHeight = safe(safeHeight * scale)

            let maxCardHeight = safe(toolbarYPosition)
            let cardHeight = safe(min(desiredCardHeight, maxCardHeight))

            let cardWidth = safe(min(desiredCardWidth, safeWidth))

            let rawHeaderHeight = (toolbarYPosition - cardHeight) / 2
            let headerHeight = safe(rawHeaderHeight)

            let rawHPadding = (safeWidth - cardWidth) / 2
            let hPadding = safe(rawHPadding)

            VStack(spacing: 0) {
                Color.clear.frame(height: headerHeight)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(tabManager.tabs) { tab in
                                let isActive = tab.id == tabManager.activeTabId
                                let hidden = tab.id == hiddenTabId
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
                                .frame(width: safe(cardWidth), height: safe(cardHeight))
                                .id(tab.id)
                                .opacity(hidden ? 0 : 1)
                                .allowsHitTesting(!hidden)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, hPadding)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                    .frame(height: safe(cardHeight))
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

    private func safe(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(0, value)
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
