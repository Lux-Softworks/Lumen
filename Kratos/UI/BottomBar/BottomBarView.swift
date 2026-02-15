import SwiftUI
import UIKit

struct BottomBarView: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    @FocusState.Binding var isFocused: Bool

    var onTabsPressed: () -> Void
    var onSettingsPressed: () -> Void
    var onSubmit: () -> Void

    @Namespace private var animation

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isExpanded ? UIScreen.main.bounds.height * 0.65 : 70, alignment: .top)

            .background(
                ZStack {
                    Rectangle()
                        .fill(.thinMaterial)
                        .opacity(0.9)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .cornerRadius(isExpanded ? 30 : 0, corners: [.topLeft, .topRight])
                        .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
                }
            )
        }
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    var expandedContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .matchedGeometryEffect(id: "magnifyingGlass", in: animation)
                    .border(Color(.systemBackground), width: 1)

                TextField("Search or enter URL", text: $text)
                    .font(.system(size: 17))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
                    .frame(height: 44)
                    .matchedGeometryEffect(id: "searchField", in: animation)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }

                Button("Cancel") {
                    withAnimation(.smooth(duration: 0.35)) {
                        isExpanded = false
                        isFocused = false
                    }
                }
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                Color.primary.opacity(0.05)
                    .clipShape(Capsule())
                    .matchedGeometryEffect(id: "searchBackground", in: animation)
            )
            .padding(.top, 16)

            Spacer()
        }
    }

    var collapsedContent: some View {
        HStack(spacing: 0) {
            Button(action: onTabsPressed) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.leading, 24)

            Spacer()

            Button(action: {
                withAnimation(.smooth(duration: 0.35)) {
                    isExpanded = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }) {
                ZStack {
                    Color.primary.opacity(0.05)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "searchBackground", in: animation)
                        .frame(width: 80, height: 44)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                        .matchedGeometryEffect(id: "magnifyingGlass", in: animation)
                }
            }

            Spacer()

            Button(action: onSettingsPressed) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.trailing, 24)
        }
        .frame(height: 60)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
