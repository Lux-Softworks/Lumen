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
        }
    }

    private var tabToggle: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.Colors.uiElement)
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
                            weight: viewModel.activeTab == .ai ? .semibold : .regular
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
                            weight: viewModel.activeTab == .folder ? .semibold : .regular
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
            vm.menuViewModel.topics = [
                Topic(name: "Technology", color: "#4A90E2", websiteCount: 12),
                Topic(name: "Science", color: "#50E3C2", websiteCount: 5),
                Topic(name: "Finance", color: "#F5A623", websiteCount: 8),
                Topic(name: "Health", color: "#D0021B", websiteCount: 3),
                Topic(name: "Art", color: "#9B59B6", websiteCount: 7),
                Topic(name: "Nature", color: "#2ECC71", websiteCount: 4),
            ]
        }
}
