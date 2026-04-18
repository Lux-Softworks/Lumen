import SwiftUI

@MainActor
struct KnowledgePanelView: View {

    @State var viewModel: KnowledgePanelViewModel
    @State private var panelWidth: CGFloat = 375 // default for iphone
    @Environment(\.palette) private var palette

    init(viewModel: KnowledgePanelViewModel? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: KnowledgePanelViewModel())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                KnowledgeAIView(viewModel: viewModel.aiViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: viewModel.activeTab == .ai ? 0 : -panelWidth)
                    .opacity(viewModel.activeTab == .ai ? 1 : 0)

                KnowledgeFolderView(viewModel: viewModel.menuViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: viewModel.activeTab == .folder ? 0 : panelWidth)
                    .opacity(viewModel.activeTab == .folder ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.smooth(duration: 0.3), value: viewModel.activeTab)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { panelWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in panelWidth = w }
                }
            )

            tabToggle
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.menuViewModel.loadTopics()
            Task { await viewModel.aiViewModel.preloadModel() }
        }
    }

    private var tabToggle: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                Capsule()
                    .fill(palette.uiElement)
                    .overlay(
                        Capsule()
                            .fill(palette.accent.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.accent.opacity(0.1), lineWidth: 0.5)
                    )
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .offset(x: viewModel.activeTab == .ai ? 0 : geo.size.width / 2)
                    .animation(.smooth(duration: 0.3), value: viewModel.activeTab)
            }

            HStack(spacing: 0) {
                Button {
                    viewModel.activeTab = .ai
                } label: {
                    Text("Ask")
                        .font(AppTheme.Typography.sansBody(
                            size: 15,
                            weight: viewModel.activeTab == .ai ? .bold : .medium
                        ))
                        .foregroundColor(
                            viewModel.activeTab == .ai
                                ? palette.text
                                : palette.text.opacity(0.45)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.activeTab = .folder
                } label: {
                    Text("Library")
                        .font(AppTheme.Typography.sansBody(
                            size: 15,
                            weight: viewModel.activeTab == .folder ? .bold : .medium
                        ))
                        .foregroundColor(
                            viewModel.activeTab == .folder
                                ? palette.text
                                : palette.text.opacity(0.45)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 38)
        .background(palette.background.opacity(0.5))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(palette.text.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0) + 8)
        .padding(.top, 8)
    }
}

#Preview {
    @Previewable @State var vm = KnowledgePanelViewModel()
    KnowledgePanelView(viewModel: vm)
        .task {
            vm.menuViewModel.topics = []
        }
}
