import SwiftUI

struct KnowledgeAIView: View {
    @Bindable var viewModel: KnowledgeAIViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Rectangle()
                .fill(AppTheme.Colors.text.opacity(0.08))
                .frame(height: 0.5)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text.opacity(0.4))

                TextField("Search what you've read...", text: $viewModel.query)
                    .font(AppTheme.Typography.sansBody(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.text)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                        viewModel.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.text.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !viewModel.query.isEmpty {
                Button {
                    Task { await viewModel.search() }
                } label: {
                    Text("Search")
                        .font(AppTheme.Typography.sansBody(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.Colors.accent)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.2), value: viewModel.query.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            loadingView
        } else if !viewModel.results.isEmpty {
            resultsList
        } else if !viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            emptyView
        } else {
            idleView
        }
    }

    private var idleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppTheme.Colors.text.opacity(0.2))
            Text("Search what you've read")
                .font(AppTheme.Typography.sansBody(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.text.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppTheme.Colors.text.opacity(0.2))
            Text("Nothing found for \"\(viewModel.query.trimmingCharacters(in: .whitespaces))\"")
                .font(AppTheme.Typography.sansBody(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.text.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    AIShimmerCard()
                }
            }
            .padding(16)
        }
    }

    private var resultsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(viewModel.results) { page in
                    AIResultCard(page: page)
                }
            }
            .padding(16)
        }
    }
}

private struct AIResultCard: View {
    let page: PageContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(page.title ?? page.domain)
                .font(AppTheme.Typography.sansBody(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.text)
                .lineLimit(2)

            Text(page.domain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.accent.opacity(0.8))

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
                    AIScrollDepthBar(depth: depth)
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

private struct AIScrollDepthBar: View {
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

private struct AIShimmerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIShimmerLine(width: .infinity, height: 14)
            AIShimmerLine(width: 200, height: 13)
            AIShimmerLine(width: .infinity, height: 13)
            AIShimmerLine(width: 140, height: 13)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.text.opacity(0.04))
        )
    }
}

private struct AIShimmerLine: View {
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
