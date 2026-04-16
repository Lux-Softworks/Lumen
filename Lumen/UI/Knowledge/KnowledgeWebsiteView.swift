import SwiftUI

@MainActor
struct KnowledgeWebsiteView: View {
    @State var viewModel: KnowledgeWebsiteViewModel
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    synthesisSection
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 20)

                    ForEach(viewModel.sessions) { session in
                        sessionSection(session)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.loadSynthesis()
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.accent)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.Colors.accent.opacity(0.1))
                        .cornerRadius(20)
                }
                Spacer()
            }
            Text(viewModel.website.displayName)
                .font(AppTheme.Typography.serifDisplay(size: 20, weight: .bold))
                .foregroundColor(AppTheme.Colors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var synthesisSection: some View {
        switch viewModel.synthesisState {
        case .idle:
            EmptyView()
        case .generating:
            synthesisShimmer
        case .ready(let text):
            synthesisCard(text: text)
        case .failed:
            EmptyView()
        }
    }

    private func synthesisCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(AppTheme.Typography.sansBody(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.Colors.accent.opacity(0.8))
                .textCase(.uppercase)
                .kerning(0.5)

            Text(text)
                .font(AppTheme.Typography.sansBody(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.07))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.14), lineWidth: 1)
            }
        )
    }

    private var synthesisShimmer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(AppTheme.Typography.sansBody(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.Colors.accent.opacity(0.8))
                .textCase(.uppercase)
                .kerning(0.5)

            VStack(alignment: .leading, spacing: 6) {
                ShimmerBar(width: .infinity, height: 13)
                ShimmerBar(width: .infinity, height: 13)
                ShimmerBar(width: 160, height: 13)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.07))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.Colors.accent.opacity(0.14), lineWidth: 1)
            }
        )
    }

    private func sessionSection(_ session: ReadingSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.headerLabel)
                .font(AppTheme.Typography.sansBody(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.text.opacity(0.4))
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(session.pages) { page in
                    pageCard(page)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func pageCard(_ page: PageContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.title ?? page.domain)
                .font(AppTheme.Typography.sansBody(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.text)
                .lineLimit(2)

            if let summary = page.summary, !summary.isEmpty {
                Text(summary)
                    .font(AppTheme.Typography.sansBody(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if let readingTime = page.readingTime, readingTime > 0 {
                    Text("\(readingTime)m")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.4))
                }

                if let depth = page.scrollDepth {
                    ScrollDepthBar(depth: depth)
                        .frame(width: 60, height: 6)
                }

                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.text.opacity(0.04))
        )
    }
}

private struct ScrollDepthBar: View {
    let depth: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Colors.text.opacity(0.1))
                Capsule()
                    .fill(AppTheme.Colors.accent.opacity(0.7))
                    .frame(width: geo.size.width * min(max(depth, 0), 1))
            }
        }
    }
}

private struct ShimmerBar: View {
    let width: CGFloat
    let height: CGFloat
    @State private var phase: CGFloat = -1

    var body: some View {
        let isInfinity = width == .infinity

        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: AppTheme.Colors.text.opacity(0.08), location: phase),
                        .init(color: AppTheme.Colors.text.opacity(0.16), location: phase + 0.3),
                        .init(color: AppTheme.Colors.text.opacity(0.08), location: phase + 0.6),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: isInfinity ? nil : width, height: height)
            .frame(maxWidth: isInfinity ? .infinity : nil)
            .clipShape(Capsule())
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

#Preview {
    let pages: [PageContent] = [
        PageContent(
            websiteID: "w1", url: "https://example.com/a",
            title: "Getting started with Swift Concurrency",
            content: "Content here",
            summary: "Covers async/await, actors, and task groups in Swift 5.5+.",
            readingTime: 8,
            scrollDepth: 0.74
        ),
        PageContent(
            websiteID: "w1", url: "https://example.com/b",
            title: "Actor isolation explained",
            content: "Content here",
            summary: "Deep dive into how actors prevent data races.",
            readingTime: 5,
            scrollDepth: 0.9
        ),
    ]
    let website = Website(domain: "example.com", displayName: "Swift.org")
    let vm = KnowledgeWebsiteViewModel(website: website, pages: pages)
    KnowledgeWebsiteView(viewModel: vm, onBack: {})
}
