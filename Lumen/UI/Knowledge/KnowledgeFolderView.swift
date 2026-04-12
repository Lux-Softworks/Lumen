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

    let cornerRadius: CGFloat = 13
    let filletRadius: CGFloat = 18
    let frontTabWidth: CGFloat = 55
    let backTabWidth: CGFloat = 75
    let tabHeight: CGFloat = 13

    private var topicColor: Color {
        if let colorStr = topic.color, let uiColor = UIColor.fromAnyString(colorStr) {
            return Color(uiColor)
        }
        return AppTheme.Colors.accent
    }

    private var rearFlapColor: Color {
        colorScheme == .dark
            ? Color(.sRGB, red: 1.0, green: 0.96, blue: 0.88, opacity: 1.0)   // cream
            : Color(.sRGB, red: 0.11, green: 0.11, blue: 0.13, opacity: 1.0)  // carbon fiber
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

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            }
            .aspectRatio(3/4, contentMode: .fit)

            Text(website.displayName)
                .font(AppTheme.Typography.sansBody(size: 13, weight: .bold))
                .foregroundColor(AppTheme.Colors.text)
                .lineLimit(1)
        }
    }
}

@MainActor
struct KnowledgeFolderView: View {
    @Bindable var viewModel: KnowledgeMenuViewModel
    @State private var animateItems = false

    var body: some View {
        ZStack {
            topicSelectionGrid
                .opacity(viewModel.currentLevel == .topics ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentLevel == .topics)

            topicKnowledgeView
                .opacity(viewModel.currentLevel == .topics ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentLevel == .topics)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topicSelectionGrid: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                if viewModel.topics.isEmpty {
                    VStack(spacing: 16) {
                        Text("No Topics Found")
                            .font(AppTheme.Typography.sansBody(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.text.opacity(0.35))

                        if seedKnowledge {
                            Button {
                                Task { await viewModel.seedData() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.square.fill.on.square.fill")
                                    Text("Seed Test Data")
                                }
                                .font(AppTheme.Typography.sansBody(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.accent)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.Colors.accent.opacity(0.1))
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
    }

    private var topicKnowledgeView: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button {
                        viewModel.navigateBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.accent)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.accent.opacity(0.1))
                            .cornerRadius(20)
                    }
                    Spacer()
                }

                Text(viewModel.selectedTopic?.name ?? "")
                    .font(AppTheme.Typography.serifDisplay(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.text)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 16)

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
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 8)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: animateItems
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onChange(of: viewModel.currentLevel) { _, newValue in
            if case .websites = newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    animateItems = true
                }
            } else {
                animateItems = false
            }
        }
    }
}

#Preview {
    @Previewable @State var vm = KnowledgeMenuViewModel()
    KnowledgeFolderView(viewModel: vm)
}
