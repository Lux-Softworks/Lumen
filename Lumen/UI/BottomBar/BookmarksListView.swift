import SwiftUI

struct BookmarksListView: View {
    var onNavigate: ((String) -> Void)?
    var onDismiss: () -> Void
    @ObservedObject private var store = PinStore.shared

    var body: some View {
        if store.all.isEmpty {
            emptyState
        } else {
            bookmarksList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppTheme.Colors.text.opacity(0.2))
            Text("No bookmarks yet")
                .font(AppTheme.Typography.sansBody(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.text.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bookmarksList: some View {
        VStack(spacing: 16) {
            group {
                ForEach(Array(store.all.enumerated()), id: \.element) { index, domain in
                    Button {
                        if let onNavigate {
                            onNavigate("https://\(domain)")
                            onDismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            faviconView(for: domain)

                            Text(domain)
                                .font(AppTheme.Typography.sansBody(size: 16, weight: .medium))
                                .foregroundColor(AppTheme.Colors.text)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.text.opacity(0.25))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < store.all.count - 1 {
                        Rectangle()
                            .fill(AppTheme.Colors.text.opacity(0.08))
                            .frame(height: 0.5)
                            .padding(.leading, 60)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func faviconView(for domain: String) -> some View {
        let pageURL = URL(string: "https://\(domain)")
        let faviconURL = pageURL.flatMap { FaviconService.faviconURL(for: $0) }

        if let faviconURL {
            AsyncImage(url: faviconURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    globeIcon
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            globeIcon
        }
    }

    private var globeIcon: some View {
        Image(systemName: "globe")
            .font(.system(size: 14))
            .foregroundColor(AppTheme.Colors.text.opacity(0.4))
            .frame(width: 22, height: 22)
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.uiElement)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.Colors.text.opacity(0.08), lineWidth: 0.5)
        )
    }
}
