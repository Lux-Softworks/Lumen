import SwiftUI

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

import SwiftUI

struct FolderItemButton: View {
    var topic: Topic
    @Environment(\.colorScheme) var colorScheme

    let cornerRadius: CGFloat = 10
    let filletRadius: CGFloat = 12
    let frontTabWidth: CGFloat = 55
    let backTabWidth: CGFloat = 75
    let tabHeight: CGFloat = 9

    private var topicColor: Color {
        if let colorStr = topic.color, let uiColor = UIColor.fromAnyString(colorStr) {
            return Color(uiColor)
        }
        return .gray
    }

    private var rearFlapColor: Color {
        Color(UIColor.fromAnyString("#2C2D30") ?? .gray)
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
                .stroke(Color.black.opacity(0.6), lineWidth: 0.5)
            }
            .frame(height: 65)

            ZStack {
                FrontFolderShape(
                    tabWidth: frontTabWidth, tabHeight: tabHeight, cornerRadius: cornerRadius,
                    filletRadius: filletRadius
                )
                .fill(topicColor)
                .blur(radius: 18)
                .opacity(0.25)
                .blendMode(colorScheme == .dark ? .plusLighter : .normal)

                BlurView(style: .systemThinMaterial)
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
                            topicColor.opacity(0.95),
                            topicColor.opacity(0.4)
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
                            Color.white.opacity(0.95),
                            topicColor.opacity(0.5),
                            Color.white.opacity(0.2)
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

@MainActor
struct KnowledgeFolderView: View {
    @Bindable var viewModel: KnowledgeMenuViewModel

    var body: some View {
        ZStack {
            topicSelectionGrid
                .opacity(viewModel.currentLevel == .topics ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentLevel == .topics)

            detailViewPlaceholder
                .opacity(viewModel.currentLevel == .topics ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentLevel == .topics)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topicSelectionGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if viewModel.topics.isEmpty {
                VStack(spacing: 16) {
                    Text("No Topics Found")
                        .font(AppTheme.Typography.sansBody(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.text.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 180)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            Task { await viewModel.clearAllTopics() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Clear All")
                            }
                            .font(AppTheme.Typography.sansBody(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.uiElement.opacity(0.3))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }

                    LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 24),
                        GridItem(.flexible(), spacing: 24),
                        GridItem(.flexible(), spacing: 24),
                    ],
                    spacing: 32
                ) {
                    ForEach(viewModel.topics) { topic in
                        Button {
                            Task { await viewModel.selectTopic(topic) }
                        } label: {
                            VStack(alignment: .center) {
                                FolderItemButton(topic: topic)

                                Text(topic.name)
                                    .font(AppTheme.Typography.sansBody(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.text)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                }
            }
        }
    }

    private var detailViewPlaceholder: some View {
        EmptyView()
    }
}

#Preview {
    @Previewable @State var vm = KnowledgeMenuViewModel()
    KnowledgeFolderView(viewModel: vm)
}
