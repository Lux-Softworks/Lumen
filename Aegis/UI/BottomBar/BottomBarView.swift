import SwiftUI

struct BottomBarView: View {
    var onTabsPressed: () -> Void
    var onSettingsPressed: () -> Void
    var onSearchPressed: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Left Button: Tabs
            Button(action: onTabsPressed) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            // Middle Button: Search/Omnibar
            Button(action: onSearchPressed) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }

            // Right Button: Settings
            Button(action: onSettingsPressed) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
