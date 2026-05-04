import SwiftUI

struct BookmarksListView: View {
    var onNavigate: ((String) -> Void)?
    var onDismiss: () -> Void
    @ObservedObject private var store = PinStore.shared
    @Environment(\.palette) private var palette

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
                .font(.largeTitle.weight(.light))
                .foregroundColor(palette.text.opacity(0.2))
            Text("No bookmarks yet")
                .font(.subheadline.weight(.medium))
                .foregroundColor(palette.text.opacity(0.3))
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
                                .font(.callout.weight(.medium))
                                .foregroundColor(palette.text)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(palette.text.opacity(0.25))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < store.all.count - 1 {
                        Rectangle()
                            .fill(palette.text.opacity(0.08))
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
        FaviconView(url: URL(string: "https://\(domain)"), size: 22, cornerRadius: 5)
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.uiElement)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.text.opacity(0.08), lineWidth: 0.5)
        )
    }
}
