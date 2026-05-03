import SwiftUI
import UIKit

struct KnowledgeAIView: View {
    @Bindable var viewModel: KnowledgeAIViewModel
    @FocusState private var isFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollWorkItem: DispatchWorkItem?
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
                    LumenSparkleMatrix(size: 18, phase: .spinning)
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
        ) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let height = max(0, frame.height - safeAreaBottom)
            withAnimation(Self.keyboardAnimation(from: notification)) { keyboardHeight = height }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
        ) { notification in
            withAnimation(Self.keyboardAnimation(from: notification)) { keyboardHeight = 0 }
        }
        .onChange(of: hasStreamingMessage) { wasStreaming, isStreaming in
            if wasStreaming && !isStreaming {
                Haptics.fire(.success)
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 14) {
            LumenSparkleMatrix(
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
        scrollWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation(AppTheme.Motion.standard) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
        scrollWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
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
                        Haptics.fire(.tap)
                        Task { await viewModel.send() }
                    }
            }

            Button {
                isFocused = false
                Haptics.fire(.tap)
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

    private static func keyboardAnimation(from notification: Notification) -> Animation {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curveRaw = (notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? 7

        switch UIView.AnimationCurve(rawValue: curveRaw) {
        case .easeIn:    return .easeIn(duration: duration)
        case .easeOut:   return .easeOut(duration: duration)
        case .linear:    return .linear(duration: duration)
        case .easeInOut: return .easeInOut(duration: duration)
        default:
            return .timingCurve(0.2, 0.8, 0.2, 1.0, duration: duration)
        }
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
            color = AppTheme.Colors.success
            icon = "checkmark.seal.fill"
        case .medium:
            color = AppTheme.Colors.warning
            icon = "exclamationmark.triangle.fill"
        case .low:
            color = AppTheme.Colors.danger.opacity(0.8)
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
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(palette.text.opacity(phase == index ? 0.4 : 0.12))
                    .frame(width: 5, height: 5)
                    .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.1), value: phase)
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

private struct LumenSparkleMatrix: View {
    let size: CGFloat
    let phase: SparklePhase

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var unlockStartedAt: Date?

    private static let lapDuration: TimeInterval = 1.5
    private static let unlockDuration: TimeInterval = 0.45
    private static let baseOpacity: Double = 0.18
    private static let tailLength: Double = 4

    private static let dotPositions: [(x: CGFloat, y: CGFloat)] = {
        let layout: [[Int]] = [
            [3],
            [3],
            [2, 3, 4],
            [0, 1, 2, 3, 4, 5, 6],
            [2, 3, 4],
            [3],
            [3]
        ]
        var result: [(CGFloat, CGFloat)] = []
        for (row, cols) in layout.enumerated() {
            let y = (CGFloat(row) - 3) / 3
            for col in cols {
                let x = (CGFloat(col) - 3) / 3
                result.append((x, y))
            }
        }
        return result
    }()

    private static let pathOrder: [Int] = [
        0, 1, 3, 2, 7, 6, 5, 6, 7, 8,
        12, 13, 15, 16, 15, 13, 14, 11, 10, 9,
        8, 4, 3, 1
    ]

    private static let dotPathPositions: [[Int]] = {
        var arr: [[Int]] = Array(repeating: [], count: LumenSparkleMatrix.dotPositions.count)
        for (i, idx) in LumenSparkleMatrix.pathOrder.enumerated() {
            arr[idx].append(i)
        }
        return arr
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas(rendersAsynchronously: false) { ctx, canvasSize in
                draw(ctx: ctx, canvasSize: canvasSize, now: context.date)
            }
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .onAppear {
            handlePhaseChange(from: phase, to: phase)
        }
        .onChange(of: phase) { oldPhase, newPhase in
            handlePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private func handlePhaseChange(from oldPhase: SparklePhase, to newPhase: SparklePhase) {
        if newPhase == .collapsing || (oldPhase == .spinning && newPhase == .idle) {
            unlockStartedAt = Date()
            Haptics.fire(.success)
        } else if newPhase == .spinning {
            unlockStartedAt = nil
        }
    }

    private func draw(ctx: GraphicsContext, canvasSize: CGSize, now: Date) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let layoutRadius = min(canvasSize.width, canvasSize.height) / 2 * 0.85
        let dotRadius = max(1.7, size * 0.08)
        let accent = palette.accent

        let timeRef = now.timeIntervalSinceReferenceDate
        let pathLen = Double(Self.pathOrder.count)
        let orbitHead = (timeRef / Self.lapDuration).truncatingRemainder(dividingBy: 1) * pathLen
        let ambientPulse = (sin(2 * Double.pi * timeRef * 0.2) + 1) / 2

        let unlockActive: Bool
        let unlockProgress: Double
        if let start = unlockStartedAt {
            let elapsed = now.timeIntervalSince(start)
            if elapsed < Self.unlockDuration {
                unlockActive = true
                unlockProgress = elapsed / Self.unlockDuration
            } else {
                unlockActive = false
                unlockProgress = 1
            }
        } else {
            unlockActive = false
            unlockProgress = 0
        }

        let effectivePhase: SparklePhase = unlockActive ? .collapsing : phase

        let scaleFactor: CGFloat
        if effectivePhase == .collapsing {
            scaleFactor = 1.0 + 0.08 * CGFloat(sin(Double.pi * unlockProgress))
        } else {
            scaleFactor = 1.0
        }

        let appliedDotRadius = dotRadius * scaleFactor

        for (idx, pos) in Self.dotPositions.enumerated() {
            let opacity = computeDotOpacity(
                dotIndex: idx,
                effectivePhase: effectivePhase,
                orbitHead: orbitHead,
                unlockProgress: unlockProgress,
                ambient: ambientPulse
            )

            let cx = center.x + pos.x * layoutRadius
            let cy = center.y + pos.y * layoutRadius

            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: cx - appliedDotRadius,
                    y: cy - appliedDotRadius,
                    width: appliedDotRadius * 2,
                    height: appliedDotRadius * 2
                )),
                with: .color(accent.opacity(opacity))
            )
        }
    }

    private func computeDotOpacity(
        dotIndex: Int,
        effectivePhase: SparklePhase,
        orbitHead: Double,
        unlockProgress u: Double,
        ambient: Double
    ) -> Double {
        if reduceMotion {
            switch effectivePhase {
            case .spinning, .collapsing:
                return 0.4 + 0.15 * ambient
            case .idle:
                return 0.3 + 0.08 * ambient
            }
        }

        let orbitOp = orbitOpacity(dotIndex: dotIndex, head: orbitHead)
        let ambientOp = 0.18 + 0.10 * ambient

        switch effectivePhase {
        case .spinning:
            return orbitOp
        case .collapsing:
            if u < 0.3 {
                let t = u / 0.3
                return orbitOp + (1.0 - orbitOp) * easeOutCubic(t)
            } else {
                let t = (u - 0.3) / 0.7
                return 1.0 - (1.0 - ambientOp) * easeOutCubic(t)
            }
        case .idle:
            return ambientOp
        }
    }

    private func orbitOpacity(dotIndex: Int, head: Double) -> Double {
        let pathLen = Double(Self.pathOrder.count)
        let positions = Self.dotPathPositions[dotIndex]
        var maxTail = 0.0
        for p in positions {
            var forward = head - Double(p)
            if forward < 0 { forward += pathLen }
            if forward < Self.tailLength {
                let f = 1 - forward / Self.tailLength
                if f > maxTail { maxTail = f }
            }
        }
        return Self.baseOpacity + (1 - Self.baseOpacity) * maxTail
    }

    private func easeOutCubic(_ t: Double) -> Double {
        let p = 1 - t
        return 1 - p * p * p
    }
}
