import SwiftUI

@MainActor
struct KnowledgeWebsiteView: View {
    @State var viewModel: KnowledgeWebsiteViewModel
    var onBack: () -> Void
    var onSelectPage: ((PageContent) -> Void)? = nil

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
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.accent.opacity(0.1))
                    .cornerRadius(20)
            }
            Text(viewModel.website.displayName)
                .font(AppTheme.Typography.sansBody(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.text)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
            .font(AppTheme.Typography.sansBody(size: 14, weight: .regular))
            .foregroundColor(AppTheme.Colors.text.opacity(0.55))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var synthesisShimmer: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShimmerBar(width: .infinity, height: 11)
            ShimmerBar(width: .infinity, height: 11)
            ShimmerBar(width: 120, height: 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sessionSection(_ session: ReadingSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.headerLabel)
                .font(AppTheme.Typography.sansBody(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.Colors.text.opacity(0.25))
                .textCase(.uppercase)
                .kerning(0.4)
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                ForEach(session.pages) { page in
                    pageCard(page)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func pageCard(_ page: PageContent) -> some View {
        Button {
            onSelectPage?(page)
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(page.title ?? page.domain)
                        .font(AppTheme.Typography.sansBody(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let summary = page.summary, !summary.isEmpty {
                        Text(summary)
                            .font(AppTheme.Typography.sansBody(size: 12, weight: .regular))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.35))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 12)

                if let readingTime = page.readingTime, readingTime > 0 {
                    Text("\(readingTime)m")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.2))
                }

                if onSelectPage != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.15))
                        .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.text.opacity(0.025))
            )
        }
        .buttonStyle(.plain)
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
