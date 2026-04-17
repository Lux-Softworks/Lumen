import SwiftUI

@MainActor
struct KnowledgePanelView: View {

    @State var viewModel: KnowledgePanelViewModel
    @State private var panelWidth: CGFloat = 375 // default for iphone

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
                    .fill(AppTheme.Colors.uiElement)
                    .overlay(
                        Capsule()
                            .fill(AppTheme.Colors.accent.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.Colors.accent.opacity(0.1), lineWidth: 0.5)
                    )
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .offset(x: viewModel.activeTab == .ai ? 0 : geo.size.width / 2)
                    .animation(.smooth(duration: 0.3), value: viewModel.activeTab)
            }

            HStack(spacing: 0) {
                Button {
                    viewModel.activeTab = .ai
                } label: {
                    Text("AI")
                        .font(AppTheme.Typography.sansBody(
                            size: 15,
                            weight: viewModel.activeTab == .ai ? .bold : .medium
                        ))
                        .foregroundColor(
                            viewModel.activeTab == .ai
                                ? AppTheme.Colors.text
                                : AppTheme.Colors.text.opacity(0.45)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.activeTab = .folder
                } label: {
                    Text("Folders")
                        .font(AppTheme.Typography.sansBody(
                            size: 15,
                            weight: viewModel.activeTab == .folder ? .bold : .medium
                        ))
                        .foregroundColor(
                            viewModel.activeTab == .folder
                                ? AppTheme.Colors.text
                                : AppTheme.Colors.text.opacity(0.45)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 38)
        .background(AppTheme.Colors.background.opacity(0.5))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.Colors.text.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
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
