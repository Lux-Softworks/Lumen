import SwiftUI
import UIKit

struct KnowledgeAIView: View {
    @Bindable var viewModel: KnowledgeAIViewModel
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

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
            .animation(AppTheme.Motion.standard, value: viewModel.messages.isEmpty)
            .animation(AppTheme.Motion.standard, value: viewModel.isThinking)

            if showThinkingIndicator {
                HStack(spacing: 8) {
                    LumenSparkle(size: 18, phase: .spinning)
                    StatusLabel(text: viewModel.statusMessage)
                }
                .padding(.leading, 16)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
                .allowsHitTesting(false)
            }

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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.text.opacity(0.28))
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
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .animation(AppTheme.Motion.standard, value: viewModel.messages.count)
                .animation(AppTheme.Motion.snappy, value: viewModel.isThinking)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isFocused = false }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isThinking) { _, thinking in
                if thinking { scrollToBottom(proxy: proxy) }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(AppTheme.Motion.standard) {
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
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(palette.text.opacity(0.3))
                            .allowsHitTesting(false)
                    }
                }
                TextField("", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.text)
                    .tint(palette.accent)
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
                    .fill(canSend ? palette.accent : palette.text.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(canSend ? .white : palette.text.opacity(0.25))
                    )
                    .animation(AppTheme.Motion.snappy, value: canSend)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(inputBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    palette.text.opacity(isFocused ? 0.18 : 0.07),
                    lineWidth: 0.75
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, isFocused ? 12 : 10)
        .padding(.bottom, isFocused ? 6 : 10)
        .animation(AppTheme.Motion.snappy, value: isFocused)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.text.opacity(colorScheme == .dark || palette.isIncognito ? 0.08 : 0.05))
    }

    private var hasStreamingMessage: Bool {
        viewModel.messages.last?.isStreaming ?? false
    }

    private var hasVisibleStreamOutput: Bool {
        guard let last = viewModel.messages.last, last.isStreaming else { return false }
        return !last.text.isEmpty
    }

    private var showThinkingIndicator: Bool {
        !viewModel.messages.isEmpty && viewModel.isThinking && !hasVisibleStreamOutput
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
    @Environment(\.palette) private var palette

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
            .foregroundColor(palette.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.uiElement)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(palette.text.opacity(0.06), lineWidth: 0.5)
                    )
            )
    }

    private var assistantView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !message.text.isEmpty {
                StreamingText(text: message.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !message.isStreaming, let match = message.sourceMatch {
                StaggeredFade(delay: 0.0) {
                    matchBadge(match)
                }
            }

            if !message.isStreaming, !message.sources.isEmpty {
                sourcesRow
            }
        }
    }

    private func matchBadge(_ match: SourceMatch) -> some View {
        let color: Color
        let icon: String
        switch match {
        case .high:
            color = Color.green
            icon = "checkmark.seal.fill"
        case .medium:
            color = Color.orange
            icon = "exclamationmark.triangle.fill"
        case .low:
            color = Color.red.opacity(0.8)
            icon = "xmark.octagon.fill"
        }
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(match.label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }

    private var sourcesRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(message.sources.enumerated()), id: \.element.id) { idx, source in
                StaggeredFade(delay: 0.12 + Double(idx) * 0.07) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(palette.accent.opacity(0.4))
                            .frame(width: 2, height: 10)
                        Text(source.domain)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(palette.text.opacity(0.35))
                            .lineLimit(1)
                        if let title = source.title, !title.isEmpty {
                            Text("· \(title)")
                                .font(.system(size: 10))
                                .foregroundColor(palette.text.opacity(0.2))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

private struct StaggeredFade<Content: View>: View {
    let delay: Double
    @ViewBuilder var content: Content
    @State private var appeared = false

    var body: some View {
        content
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 3)
            .onAppear {
                withAnimation(.easeOut(duration: 0.32).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct StreamingText: View {
    let text: String
    @Environment(\.palette) private var palette

    private struct Line: Identifiable {
        let id: Int
        let tokens: [(word: String, bold: Bool)]
        let isBullet: Bool
        let startIndex: Int
    }

    private enum Block: Identifiable {
        case prose(id: Int, lines: [Line])
        case code(id: Int, body: String)
        var id: Int {
            switch self {
            case .prose(let id, _): return id
            case .code(let id, _): return id
            }
        }
    }

    var body: some View {
        let blocks = parseBlocks(text)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                switch block {
                case .prose(_, let lines):
                    proseView(lines: lines)
                case .code(_, let body):
                    codeView(body: body)
                }
            }
        }
    }

    @ViewBuilder
    private func proseView(lines: [Line]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines) { line in
                HStack(alignment: .top, spacing: 6) {
                    if line.isBullet {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(palette.accent.opacity(0.6))
                            .padding(.top, 1)
                    }
                    WordFlowLayout(wordSpacing: 4, lineSpacing: 5) {
                        ForEach(Array(line.tokens.enumerated()), id: \.offset) { i, token in
                            FadingWord(
                                word: token.word,
                                bold: token.bold,
                                globalIndex: line.startIndex + i
                            )
                            .id(line.startIndex + i)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func codeView(body: String) -> some View {
        Text(body)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(palette.text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(palette.text.opacity(0.06))
            )
    }

    private func parseBlocks(_ raw: String) -> [Block] {
        var blocks: [Block] = []
        var blockID = 0
        var proseAccum: [String] = []
        var codeAccum: [String] = []
        var inFence = false
        var globalOffset = 0

        func flushProse() {
            guard !proseAccum.isEmpty else { return }
            let (lines, consumed) = linesFrom(proseAccum, startIndex: globalOffset)
            if !lines.isEmpty {
                blocks.append(.prose(id: blockID, lines: lines))
                blockID += 1
                globalOffset += consumed
            }
            proseAccum.removeAll()
        }

        func flushCode() {
            let joined = codeAccum.joined(separator: "\n")
            let body = joined.trimmingCharacters(in: .newlines)
            if !body.isEmpty {
                blocks.append(.code(id: blockID, body: body))
                blockID += 1
            }
            codeAccum.removeAll()
        }

        for rawLine in raw.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inFence {
                    flushCode()
                    inFence = false
                } else {
                    flushProse()
                    inFence = true
                }
                continue
            }
            if inFence {
                codeAccum.append(rawLine)
            } else {
                proseAccum.append(rawLine)
            }
        }

        if inFence {
            flushCode()
        } else {
            flushProse()
        }
        return blocks
    }

    private func linesFrom(_ rawLines: [String], startIndex: Int) -> (lines: [Line], consumed: Int) {
        var lines: [Line] = []
        var offset = startIndex
        var id = 0
        for rawLine in rawLines {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            var content = trimmedLine
            var isBullet = false
            if content.hasPrefix("- ") || content.hasPrefix("• ") || content.hasPrefix("* ") {
                content = String(content.dropFirst(2))
                isBullet = true
            }
            let tokens = tokenize(content)
            lines.append(Line(id: id, tokens: tokens, isBullet: isBullet, startIndex: offset))
            offset += tokens.count
            id += 1
        }
        return (lines, offset - startIndex)
    }

    private func tokenize(_ raw: String) -> [(word: String, bold: Bool)] {
        var tokens: [(String, Bool)] = []
        let segments = raw.components(separatedBy: "**")
        for (i, segment) in segments.enumerated() {
            let bold = !i.isMultiple(of: 2)
            for word in segment.split(whereSeparator: { $0.isWhitespace }) {
                tokens.append((String(word), bold))
            }
        }
        return tokens
    }
}

private struct FadingWord: View {
    let word: String
    let bold: Bool
    let globalIndex: Int
    @State private var appeared = false
    @Environment(\.palette) private var palette

    var body: some View {
        Text(word)
            .font(.system(size: 15, weight: bold ? .bold : .regular))
            .foregroundColor(palette.text)
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) {
                    appeared = true
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
    @Environment(\.palette) private var palette
    @State private var revealComplete = false

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
        let totalTokens = offset
        let finalDelay = Double(max(0, totalTokens - 1)) * 0.025 + 0.26

        Group {
            if revealComplete {
                staticContent(indexed: indexed)
            } else {
                animatedContent(indexed: indexed)
                    .task(id: text) {
                        try? await Task.sleep(nanoseconds: UInt64(finalDelay * 1_000_000_000))
                        if !Task.isCancelled { revealComplete = true }
                    }
            }
        }
    }

    @ViewBuilder
    private func animatedContent(indexed: [IndexedBlock]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(indexed.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    if item.block.isBullet {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(palette.accent.opacity(0.6))
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

    @ViewBuilder
    private func staticContent(indexed: [IndexedBlock]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(indexed.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    if item.block.isBullet {
                        Text("•")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(palette.accent.opacity(0.6))
                            .padding(.top, 1)
                    }

                    WordFlowLayout(wordSpacing: 4, lineSpacing: 5) {
                        ForEach(Array(item.block.tokens.enumerated()), id: \.offset) { _, token in
                            StaticWord(word: token.word, bold: token.bold)
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
    @Environment(\.palette) private var palette

    var body: some View {
        Text(word)
            .font(.system(size: 15, weight: bold ? .bold : .regular))
            .foregroundColor(palette.text)
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared ? 0 : 2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct StaticWord: View {
    let word: String
    let bold: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Text(word)
            .font(.system(size: 15, weight: bold ? .bold : .regular))
            .foregroundColor(palette.text)
    }
}

private struct ThreeDotsView: View {
    @State private var phase: Int = 0
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(palette.text.opacity(phase == i ? 0.4 : 0.12))
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

private struct StatusLabel: View {
    let text: String?
    @Environment(\.palette) private var palette

    private var isHidden: Bool { (text ?? "").isEmpty }

    var body: some View {
        Text(text ?? "")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(palette.text.opacity(0.5))
            .opacity(isHidden ? 0 : 1)
            .blur(radius: isHidden ? 2 : 0)
            .animation(.easeOut(duration: 0.25), value: text)
    }
}

private struct LumenSparkle: View {
    let size: CGFloat
    let phase: SparklePhase

    @State private var isSpinning = false
    @Environment(\.palette) private var palette
    @State private var tickSpread: Double = 0
    @State private var tickOpacity: Double = 0
    @State private var glowOpacity: Double = 0.2
    @State private var glowScale: Double = 1.0

    private let tickCount = 8

    var body: some View {
        ZStack {
            if isSpinning {
                TimelineView(.animation) { timeline in
                    let angle = timeline.date.timeIntervalSinceReferenceDate * 120
                    ZStack {
                        ForEach(0..<tickCount, id: \.self) { i in
                            Capsule()
                                .fill(palette.accent)
                                .frame(width: 1.5, height: size * 0.2)
                                .offset(y: -(size * 0.75 * tickSpread))
                                .rotationEffect(
                                    .degrees(Double(i) * (360.0 / Double(tickCount)) + angle)
                                )
                                .opacity(tickOpacity)
                        }
                    }
                }
            }

            Image(systemName: "sparkle")
                .font(.system(size: size * 1.2, weight: .thin))
                .foregroundColor(palette.accent)
                .blur(radius: size * 0.22)
                .opacity(glowOpacity)
                .scaleEffect(glowScale)

            Image(systemName: "sparkle")
                .font(.system(size: size, weight: .thin))
                .foregroundColor(palette.accent)
        }
        .frame(width: size * 1.7, height: size * 1.7)
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
