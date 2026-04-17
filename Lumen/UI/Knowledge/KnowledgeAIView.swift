import SwiftUI
import UIKit

struct KnowledgeAIView: View {
    @Bindable var viewModel: KnowledgeAIViewModel
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if viewModel.messages.isEmpty && !viewModel.isThinking {
                    idleView
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    messageList
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.smooth(duration: 0.28), value: viewModel.messages.isEmpty)
            .animation(.smooth(duration: 0.28), value: viewModel.isThinking)

            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, keyboardHeight)
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        ) { n in
            guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            let height = max(0, frame.height - safeAreaBottom)
            withAnimation(.spring(duration: dur * 0.85, bounce: 0)) { keyboardHeight = height }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { n in
            let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            withAnimation(.easeOut(duration: dur * 0.9)) { keyboardHeight = 0 }
        }
    }

    private var idleView: some View {
        VStack(spacing: 14) {
            LumenSparkle(
                size: 38,
                phase: viewModel.isModelLoading ? .spinning : viewModel.sparklePhase
            )
            Text("Ask about what you've read")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.Colors.text.opacity(0.28))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = false }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.messages) { message in
                        ChatBubbleView(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    if viewModel.isThinking {
                        LumenSparkle(size: 22, phase: viewModel.sparklePhase)
                            .id("thinking")
                            .padding(.leading, 4)
                            .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .animation(.smooth(duration: 0.32), value: viewModel.messages.count)
                .animation(.smooth(duration: 0.22), value: viewModel.isThinking)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isFocused = false }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isThinking) { _, thinking in
                if thinking { scrollToBottom(proxy: proxy) }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.smooth(duration: 0.4)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .leading) {
                if viewModel.inputText.isEmpty {
                    if viewModel.isModelLoading {
                        ThreeDotsView()
                            .allowsHitTesting(false)
                    } else {
                        Text("What do you want to know?")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.3))
                            .allowsHitTesting(false)
                    }
                }
                TextField("", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.text)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .disabled(viewModel.isModelLoading)
                    .onSubmit {
                        guard canSend else { return }
                        Task { await viewModel.send() }
                    }
            }

            Button {
                isFocused = false
                Task { await viewModel.send() }
            } label: {
                Circle()
                    .fill(canSend ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(canSend ? .white : AppTheme.Colors.text.opacity(0.25))
                    )
                    .animation(.spring(duration: 0.25, bounce: 0.25), value: canSend)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(inputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    AppTheme.Colors.text.opacity(isFocused ? 0.18 : 0.07),
                    lineWidth: 0.75
                )
        )
        .animation(.smooth(duration: 0.18), value: isFocused)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var inputBackground: some View {
        ZStack {
            BlurView(style: .systemThickMaterial)

            LinearGradient(
                colors: [
                    AppTheme.Colors.uiElement.opacity(0.25),
                    AppTheme.Colors.uiElement.opacity(0.12),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
            && !viewModel.isThinking
            && !viewModel.isModelLoading
    }
}

private struct ChatBubbleView: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        Group {
            if isUser {
                HStack { Spacer(minLength: 60); userBubble }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                assistantView
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var userBubble: some View {
        Text(message.text)
            .font(.system(size: 15))
            .foregroundColor(AppTheme.Colors.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.Colors.uiElement)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(AppTheme.Colors.text.opacity(0.06), lineWidth: 0.5)
                    )
            )
    }

    private var assistantView: some View {
        VStack(alignment: .leading, spacing: 10) {
            RevealText(text: message.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !message.sources.isEmpty {
                sourcesRow
            }
        }
    }

    private var sourcesRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(message.sources) { source in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(AppTheme.Colors.accent.opacity(0.4))
                        .frame(width: 2, height: 10)
                    Text(source.domain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.35))
                        .lineLimit(1)
                    if let title = source.title, !title.isEmpty {
                        Text("· \(title)")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.2))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct WordFlowLayout: Layout {
    var wordSpacing: CGFloat = 4
    var lineSpacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(
                at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + wordSpacing
            totalWidth = max(totalWidth, x - wordSpacing)
        }

        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}

private struct RevealText: View {
    let text: String

    private struct WordToken {
        let word: String
        let bold: Bool
    }

    private struct LineBlock {
        let tokens: [WordToken]
        let isBullet: Bool
    }

    private struct IndexedBlock {
        let block: LineBlock
        let startIndex: Int
    }

    var body: some View {
        let blocks = parseBlocks(text)
        var offset = 0
        let indexed = blocks.map { block -> IndexedBlock in
            let start = offset
            offset += block.tokens.count
            return IndexedBlock(block: block, startIndex: start)
        }

        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(indexed.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    if item.block.isBullet {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.Colors.accent.opacity(0.6))
                            .padding(.top, 1)
                    }

                    WordFlowLayout(wordSpacing: 4, lineSpacing: 5) {
                        ForEach(Array(item.block.tokens.enumerated()), id: \.offset) { i, token in
                            WordView(
                                word: token.word,
                                bold: token.bold,
                                delay: Double(item.startIndex + i) * 0.025
                            )
                        }
                    }
                }
            }
        }
    }

    private func parseBlocks(_ raw: String) -> [LineBlock] {
        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.map { line in
            var content = line
            var isBullet = false

            if content.hasPrefix("- ") || content.hasPrefix("• ") || content.hasPrefix("* ") {
                content = String(content.dropFirst(2))
                isBullet = true
            }

            let tokens = tokenizeLine(content)
            return LineBlock(tokens: tokens, isBullet: isBullet)
        }
    }

    private func tokenizeLine(_ raw: String) -> [WordToken] {
        var tokens: [WordToken] = []
        let segments = raw.components(separatedBy: "**")
        for (i, segment) in segments.enumerated() {
            guard !segment.isEmpty else { continue }
            let bold = !i.isMultiple(of: 2)
            for word in segment.split(whereSeparator: { $0.isWhitespace }) {
                tokens.append(WordToken(word: String(word), bold: bold))
            }
        }
        var merged: [WordToken] = []
        for token in tokens {
            if token.word.allSatisfy({ $0.isPunctuation || $0.isSymbol }) && !merged.isEmpty {
                let prev = merged.removeLast()
                merged.append(WordToken(word: prev.word + token.word, bold: prev.bold))
            } else {
                merged.append(token)
            }
        }
        return merged
    }
}

private struct WordView: View {
    let word: String
    let bold: Bool
    let delay: Double

    @State private var appeared = false

    var body: some View {
        Text(word)
            .font(.system(size: 15, weight: bold ? .bold : .regular))
            .foregroundColor(AppTheme.Colors.text)
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct ThreeDotsView: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppTheme.Colors.text.opacity(phase == i ? 0.4 : 0.12))
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.1), value: phase)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 450_000_000)
                phase = (phase + 1) % 3
            }
        }
    }
}

private struct LumenSparkle: View {
    let size: CGFloat
    let phase: SparklePhase

    @State private var isSpinning = false
    @State private var tickSpread: Double = 0
    @State private var tickOpacity: Double = 0
    @State private var glowOpacity: Double = 0.2
    @State private var glowScale: Double = 1.0

    private let tickCount = 8

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isSpinning)) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate * 120

            ZStack {
                ForEach(0..<tickCount, id: \.self) { i in
                    Capsule()
                        .fill(AppTheme.Colors.accent)
                        .frame(width: 1.5, height: size * 0.2)
                        .offset(y: -(size * 0.75 * tickSpread))
                        .rotationEffect(
                            .degrees(Double(i) * (360.0 / Double(tickCount)) + angle)
                        )
                        .opacity(tickOpacity)
                }

                Image(systemName: "sparkle")
                    .font(.system(size: size * 1.2, weight: .thin))
                    .foregroundColor(AppTheme.Colors.accent)
                    .blur(radius: size * 0.22)
                    .opacity(glowOpacity)
                    .scaleEffect(glowScale)

                Image(systemName: "sparkle")
                    .font(.system(size: size, weight: .thin))
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
        .frame(width: size * 2.4, height: size * 2.4)
        .onChange(of: phase) { _, newPhase in
            applyPhase(newPhase)
        }
        .onAppear {
            applyPhase(phase)
        }
    }

    private func applyPhase(_ p: SparklePhase) {
        switch p {
        case .idle:
            isSpinning = false
            withAnimation(.easeOut(duration: 0.3)) {
                tickSpread = 0
                tickOpacity = 0
                glowOpacity = 0.2
                glowScale = 1.0
            }
        case .spinning:
            isSpinning = true
            withAnimation(.spring(duration: 0.45, bounce: 0.1)) {
                tickSpread = 1
                tickOpacity = 0.55
                glowOpacity = 0.35
                glowScale = 1.05
            }
        case .collapsing:
            withAnimation(.spring(duration: 0.8, bounce: 0.05)) {
                tickSpread = 0
            }
            withAnimation(.smooth(duration: 0.65)) {
                tickOpacity = 0
                glowOpacity = 0.15
                glowScale = 0.95
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                isSpinning = false
            }
        }
    }
}
