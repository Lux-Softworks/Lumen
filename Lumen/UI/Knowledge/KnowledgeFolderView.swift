import SwiftUI

struct FrontFolderShape: Shape {
    var tabWidth: CGFloat
    var tabHeight: CGFloat
    var cornerRadius: CGFloat
    var filletRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let baseCornerRadius = cornerRadius

        let tabCornerRadius = min(cornerRadius, tabHeight / 2)
        let tabFilletRadius = min(filletRadius, tabHeight / 2)

        path.move(to: CGPoint(x: 0, y: height - baseCornerRadius))
        path.addLine(to: CGPoint(x: 0, y: tabCornerRadius))
        path.addQuadCurve(to: CGPoint(x: tabCornerRadius, y: 0), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: tabWidth - tabCornerRadius - tabFilletRadius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: tabWidth - tabFilletRadius, y: tabCornerRadius), control: CGPoint(x: tabWidth - tabFilletRadius, y: 0))
        path.addLine(to: CGPoint(x: tabWidth - tabFilletRadius, y: tabHeight - tabFilletRadius))
        path.addQuadCurve(
            to: CGPoint(x: tabWidth, y: tabHeight), control: CGPoint(x: tabWidth - tabFilletRadius, y: tabHeight)
        )
        path.addLine(to: CGPoint(x: width - baseCornerRadius, y: tabHeight))
        path.addQuadCurve(
            to: CGPoint(x: width, y: tabHeight + baseCornerRadius), control: CGPoint(x: width, y: tabHeight))
        path.addLine(to: CGPoint(x: width, y: height - baseCornerRadius))
        path.addQuadCurve(to: CGPoint(x: width - baseCornerRadius, y: height), control: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: baseCornerRadius, y: height))
        path.addQuadCurve(to: CGPoint(x: 0, y: height - baseCornerRadius), control: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

struct BackFolderShape: Shape {
    var tabWidth: CGFloat
    var tabHeight: CGFloat
    var cornerRadius: CGFloat
    var filletRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let baseCornerRadius = cornerRadius

        let tabCornerRadius = min(cornerRadius, tabHeight / 2)
        let tabFilletRadius = min(filletRadius, tabHeight / 2)

        path.move(to: CGPoint(x: baseCornerRadius, y: tabHeight))
        path.addLine(to: CGPoint(x: width - tabWidth, y: tabHeight))
        path.addQuadCurve(
            to: CGPoint(x: width - tabWidth + tabFilletRadius, y: tabHeight - tabFilletRadius),
            control: CGPoint(x: width - tabWidth, y: tabHeight))
        path.addLine(to: CGPoint(x: width - tabWidth + tabFilletRadius, y: tabCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: width - tabWidth + tabFilletRadius + tabCornerRadius, y: 0),
            control: CGPoint(x: width - tabWidth + tabFilletRadius, y: 0))
        path.addLine(to: CGPoint(x: width - tabCornerRadius, y: 0))
        path.addQuadCurve(to: CGPoint(x: width, y: tabCornerRadius), control: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height - baseCornerRadius))
        path.addQuadCurve(to: CGPoint(x: width - baseCornerRadius, y: height), control: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: baseCornerRadius, y: height))
        path.addQuadCurve(to: CGPoint(x: 0, y: height - baseCornerRadius), control: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: tabHeight + baseCornerRadius))
        path.addQuadCurve(to: CGPoint(x: baseCornerRadius, y: tabHeight), control: CGPoint(x: 0, y: tabHeight))
        path.closeSubpath()
        return path
    }
}

struct FolderItemButton: View {
    var topic: Topic
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.palette) private var palette

    let cornerRadius: CGFloat = 13
    let filletRadius: CGFloat = 18
    let frontTabWidth: CGFloat = 55
    let backTabWidth: CGFloat = 75
    let tabHeight: CGFloat = 13

    private var topicColor: Color {
        if let colorStr = topic.color, let uiColor = UIColor.fromAnyString(colorStr) {
            return Color(uiColor)
        }
        return palette.accent
    }

    private var rearFlapColor: Color {
        colorScheme == .dark
            ? Color(.sRGB, red: 1.0, green: 0.96, blue: 0.88, opacity: 1.0)
            : Color(.sRGB, red: 0.11, green: 0.11, blue: 0.13, opacity: 1.0)
    }

    private var rearFlapStrokeColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.12)
            : Color.white.opacity(0.07)
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            ZStack {
                BackFolderShape(
                    tabWidth: backTabWidth, tabHeight: tabHeight, cornerRadius: cornerRadius,
                    filletRadius: filletRadius
                )
                .fill(rearFlapColor)

                BackFolderShape(
                    tabWidth: backTabWidth, tabHeight: tabHeight, cornerRadius: cornerRadius,
                    filletRadius: filletRadius
                )
                .stroke(rearFlapStrokeColor, lineWidth: 0.5)
            }
            .frame(height: 65)

            ZStack {
                FrontFolderShape(
                    tabWidth: frontTabWidth, tabHeight: tabHeight, cornerRadius: cornerRadius,
                    filletRadius: filletRadius
                )
                .fill(topicColor)
                .blur(radius: 18)
                .opacity(0.28)
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)

                BlurView(style: .systemUltraThinMaterial)
                    .clipShape(
                        FrontFolderShape(
                            tabWidth: frontTabWidth, tabHeight: tabHeight,
                            cornerRadius: cornerRadius, filletRadius: filletRadius))

                FrontFolderShape(
                    tabWidth: frontTabWidth, tabHeight: tabHeight, cornerRadius: cornerRadius,
                    filletRadius: filletRadius
                )
                .fill(
                    LinearGradient(
                        colors: [
                            topicColor.opacity(0.38),
                            topicColor.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                FrontFolderShape(
                    tabWidth: frontTabWidth, tabHeight: tabHeight, cornerRadius: cornerRadius,
                    filletRadius: filletRadius
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            topicColor.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
            }
            .frame(height: 60)

        }
        .frame(maxWidth: .infinity)
    }
}

struct WebsitePageButton: View {
    var website: Website
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.uiElement)
                    .shadow(color: palette.text.opacity(0.06), radius: 6, x: 0, y: 3)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.text.opacity(0.06), lineWidth: 0.5)
            }
            .aspectRatio(3/4, contentMode: .fit)

            Text(website.displayName)
                .font(AppTheme.Typography.sansBody(size: 13, weight: .bold))
                .foregroundColor(palette.text)
                .lineLimit(1)
        }
    }
}

@MainActor
struct KnowledgeFolderView: View {
    @Bindable var viewModel: KnowledgeMenuViewModel

    @State private var pressedTopicID: String? = nil
    @State private var topicToDelete: Topic? = nil
    @State private var showDeleteAlert = false
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                topicSelectionGrid
                    .frame(width: width)
                    .offset(x: offsetFor(index: 0, width: width))
                    .opacity(opacityFor(index: 0))

                topicKnowledgeView
                    .frame(width: width)
                    .offset(x: offsetFor(index: 1, width: width))
                    .opacity(opacityFor(index: 1))

                pagesView
                    .frame(width: width)
                    .offset(x: offsetFor(index: 2, width: width))
                    .opacity(opacityFor(index: 2))

                detailView
                    .frame(width: width)
                    .offset(x: offsetFor(index: 3, width: width))
                    .opacity(opacityFor(index: 3))
            }
            .animation(.smooth(duration: 0.3), value: viewModel.navigationPath)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func offsetFor(index: Int, width: CGFloat) -> CGFloat {
        if index == levelIndex { return 0 }
        if index < levelIndex { return -width * 0.25 }
        return width
    }

    private func opacityFor(index: Int) -> Double {
        if index == levelIndex { return 1.0 }
        if abs(index - levelIndex) == 1 { return 0.0 }
        return 0.0
    }

    private var levelIndex: Int {
        switch viewModel.currentLevel {
        case .topics: return 0
        case .websites: return 1
        case .pages: return 2
        case .detail: return 3
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let page = viewModel.selectedPage {
            PageDetailView(page: page, onBack: { viewModel.navigateBack() })
                .id(page.id)
        }
    }

    private var topicSelectionGrid: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                if viewModel.topics.isEmpty {
                    VStack(spacing: 16) {
                        Text("No Topics Found")
                            .font(AppTheme.Typography.sansBody(size: 16, weight: .semibold))
                            .foregroundColor(palette.text.opacity(0.35))

                        if seedKnowledge {
                            Button {
                                Task { await viewModel.seedData() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.square.fill.on.square.fill")
                                    Text("Seed Test Data")
                                }
                                .font(AppTheme.Typography.sansBody(size: 14, weight: .bold))
                                .foregroundColor(palette.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(palette.accent.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 180)
                } else {
                    VStack(spacing: 0) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 24),
                                GridItem(.flexible(), spacing: 24),
                                GridItem(.flexible(), spacing: 24),
                            ],
                            spacing: 32
                        ) {
                            ForEach(Array(viewModel.topics.enumerated()), id: \.element.id) { index, topic in
                                Button {
                                    Task { await viewModel.selectTopic(topic) }
                                } label: {
                                    VStack(alignment: .center) {
                                        FolderItemButton(topic: topic)
                                            .scaleEffect(pressedTopicID == topic.id ? 0.88 : 1.0)
                                            .animation(
                                                .spring(response: 0.25, dampingFraction: 0.6),
                                                value: pressedTopicID
                                            )

                                        Text(topic.name)
                                            .font(AppTheme.Typography.sansBody(size: 13, weight: .bold))
                                            .foregroundColor(palette.text)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .modifier(StaggerFadeModifier(delay: Double(index) * 0.04))
                                .highPriorityGesture(
                                    LongPressGesture(minimumDuration: 0.45)
                                        .onEnded { _ in
                                            pressedTopicID = topic.id
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                            topicToDelete = topic
                                            showDeleteAlert = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                pressedTopicID = nil
                                            }
                                        }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .alert(
                            "Delete \"\(topicToDelete?.name ?? "Folder")\"?",
                            isPresented: $showDeleteAlert,
                            presenting: topicToDelete
                        ) { topic in
                            Button("Delete", role: .destructive) {
                                Task { await viewModel.deleteTopic(topic) }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: { _ in
                            Text("All websites and saved pages inside this folder will be permanently deleted.")
                        }
                    }
                }
            }
        }
    }

    private var topicKnowledgeView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    viewModel.navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(palette.accent)
                        .frame(width: 40, height: 40)
                        .background(palette.accent.opacity(0.1))
                        .cornerRadius(20)
                }
                Text(viewModel.selectedTopic?.name ?? "")
                    .font(AppTheme.Typography.sansBody(size: 17, weight: .bold))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                ], spacing: 24) {
                    ForEach(Array(viewModel.websites.enumerated()), id: \.element.id) { index, website in
                        Button {
                            Task { await viewModel.selectWebsite(website) }
                        } label: {
                            WebsitePageButton(website: website)
                        }
                        .buttonStyle(.plain)
                        .modifier(StaggerFadeModifier(delay: Double(index) * 0.05))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var pagesView: some View {
        if let websiteVM = viewModel.websiteViewModel {
            KnowledgeWebsiteView(viewModel: websiteVM, onBack: {
                viewModel.navigateBack()
            }, onSelectPage: { page in
                viewModel.selectPage(page)
            })
        }
    }
}

private struct StaggerFadeModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .blur(radius: appeared ? 0 : 2)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    appeared = true
                }
            }
    }
}

private struct PageDetailView: View {
    let page: PageContent
    var onBack: () -> Void

    @State private var annotations: [Annotation] = []
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(palette.accent)
                        .frame(width: 40, height: 40)
                        .background(palette.accent.opacity(0.1))
                        .cornerRadius(20)
                }
                Text(page.title ?? page.domain)
                    .font(AppTheme.Typography.sansBody(size: 17, weight: .bold))
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if let summary = page.summary, !summary.isEmpty {
                        Text((try? AttributedString(markdown: summary)) ?? AttributedString(summary))
                            .font(AppTheme.Typography.sansBody(size: 14, weight: .regular))
                            .foregroundColor(palette.text.opacity(0.5))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }

                    if let meta = pageMetaLine {
                        Text(meta)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(palette.text.opacity(0.25))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }

                    if !annotations.isEmpty {
                        highlightsSection
                            .padding(.bottom, 20)
                            .transition(.opacity)
                    }

                    Rectangle()
                        .fill(palette.text.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(contentParagraphs.enumerated()), id: \.offset) { _, para in
                            Text(para)
                                .font(AppTheme.Typography.sansBody(size: 15, weight: .regular))
                                .foregroundColor(palette.text.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(5)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
                .animation(.smooth(duration: 0.25), value: annotations.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadAnnotations() }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlights")
                .font(AppTheme.Typography.sansBody(size: 11, weight: .semibold))
                .foregroundColor(palette.text.opacity(0.35))
                .textCase(.uppercase)
                .kerning(0.4)
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                ForEach(annotations) { annotation in
                    annotationRow(annotation)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func annotationRow(_ annotation: Annotation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(red: 1.0, green: 0.84, blue: 0.4))
                .frame(width: 3)

            Text(annotation.text)
                .font(AppTheme.Typography.sansBody(size: 13, weight: .regular))
                .foregroundColor(palette.text.opacity(0.75))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await delete(annotation) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(palette.text.opacity(0.3))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.text.opacity(0.025))
        )
    }

    private func loadAnnotations() async {
        let loaded = (try? await KnowledgeStorage.shared.fetchAnnotations(pageID: page.id)) ?? []
        await MainActor.run { annotations = loaded }
    }

    private func delete(_ annotation: Annotation) async {
        try? await KnowledgeStorage.shared.deleteAnnotation(id: annotation.id)
        let refreshed = (try? await KnowledgeStorage.shared.fetchAnnotations(pageID: page.id)) ?? []
        await MainActor.run {
            withAnimation(.smooth(duration: 0.25)) { annotations = refreshed }
        }
    }

    private var contentParagraphs: [String] {
        page.content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var pageMetaLine: String? {
        var parts: [String] = []
        parts.append(page.domain)
        if let time = page.readingTime, time > 0 {
            parts.append("\(time) min read")
        }
        if let depth = page.scrollDepth, depth > 0 {
            parts.append("\(Int(depth * 100))% read")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    @Previewable @State var vm = KnowledgeMenuViewModel()
    KnowledgeFolderView(viewModel: vm)
}
