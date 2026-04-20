import SwiftUI
import UIKit

struct ExportView: View {
    enum Scope: Hashable {
        case wholeBase
        case topic
        case site
        case page
        case dateRange
    }

    var initialScope: Scope = .wholeBase
    var fixedCoordinatorScope: ExportCoordinator.Request.Scope? = nil
    var onDismiss: () -> Void

    @Environment(\.palette) private var palette
    @State private var scope: Scope = .wholeBase
    @State private var includeAnnotations: Bool = true
    @State private var includeAISummaries: Bool = true
    @State private var includeEmbeddings: Bool = true
    @State private var includeTimestamps: Bool = true
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    @State private var exportProgress: ExportCoordinator.Progress? = nil
    @State private var lastTotal: Int = 1
    @State private var shareItem: ShareItem? = nil
    @State private var activeTask: Task<Void, Never>? = nil
    @State private var progressGateVisible: Bool = false
    @State private var gateTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            if fixedCoordinatorScope != nil {
                sheetHeader
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if fixedCoordinatorScope == nil {
                        scopeCard
                        if scope == .dateRange { dateRangeCard }
                    } else {
                        fixedScopeHeader
                    }
                    togglesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)

            footerArea
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .onAppear { scope = initialScope }
        .sheet(item: $shareItem, onDismiss: {
            exportProgress = nil
            progressGateVisible = false
            gateTask?.cancel()
            gateTask = nil
        }) { item in
            ShareSheet(url: item.url)
        }
        .alert("Export Failed", isPresented: Binding(
            get: { failureMessage != nil },
            set: { if !$0 { exportProgress = nil } }
        )) {
            Button("OK", role: .cancel) { exportProgress = nil }
        } message: {
            Text(failureMessage ?? "")
        }
    }

    private var failureMessage: String? {
        if case .failed(let msg) = exportProgress { return msg }
        return nil
    }

    private var isRunning: Bool {
        guard let p = exportProgress else { return false }
        switch p {
        case .fetching, .writing, .zipping: return true
        default: return false
        }
    }

    private static let progressGateDelay: UInt64 = 400_000_000

    private var isProgressVisible: Bool {
        guard progressGateVisible, let p = exportProgress else { return false }
        switch p {
        case .fetching, .writing, .zipping, .finished: return true
        case .cancelled, .failed: return false
        }
    }

    private var sheetHeader: some View {
        ZStack {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(palette.accent)
                        .frame(width: 40, height: 40)
                        .background(palette.accent.opacity(0.1))
                        .cornerRadius(20)
                }
                Spacer()
            }
            Text("Export")
                .font(AppTheme.Typography.display(size: 20, weight: .bold))
                .foregroundColor(palette.text)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var fixedScopeHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: fixedScopeIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(palette.accent)
                .frame(width: 32, height: 32)
            Text(fixedScopeTitle)
                .font(AppTheme.Typography.sansBody(size: 16, weight: .bold))
                .foregroundColor(palette.text)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.uiElement))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.text.opacity(0.08), lineWidth: 0.5))
    }

    private var fixedScopeIcon: String {
        switch fixedCoordinatorScope {
        case .topic: return "folder"
        case .site: return "globe"
        case .page: return "doc.text"
        case .dateRange: return "calendar"
        case .wholeBase, .none: return "square.grid.3x3"
        }
    }

    private var fixedScopeTitle: String {
        switch fixedCoordinatorScope {
        case .topic: return "Export Topic"
        case .site: return "Export Site"
        case .page: return "Export Page"
        case .dateRange: return "Export Date Range"
        case .wholeBase, .none: return "Export Knowledge Base"
        }
    }

    private var scopeCard: some View {
        VStack(spacing: 0) {
            scopeRow(.wholeBase, icon: "square.grid.3x3", title: "Whole Knowledge Base")
            divider
            scopeRow(.topic, icon: "folder", title: "Current Topic")
            divider
            scopeRow(.site, icon: "globe", title: "Current Site")
            divider
            scopeRow(.page, icon: "doc.text", title: "Current Page")
            divider
            scopeRow(.dateRange, icon: "calendar", title: "Date Range")
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.uiElement))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.text.opacity(0.08), lineWidth: 0.5))
    }

    private func scopeRow(_ value: Scope, icon: String, title: String) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { scope = value }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(scope == value ? palette.accent : palette.text.opacity(0.4))
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(AppTheme.Typography.sansBody(size: 16, weight: scope == value ? .bold : .medium))
                    .foregroundColor(scope == value ? palette.accent : palette.text)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.text.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    private var togglesCard: some View {
        VStack(spacing: 0) {
            toggleRow(icon: "highlighter", title: "Include Highlights", isOn: $includeAnnotations)
            divider
            toggleRow(icon: "sparkle", title: "Include AI Summaries", isOn: $includeAISummaries)
            divider
            toggleRow(icon: "cube.transparent", title: "Include Embeddings", isOn: $includeEmbeddings)
            divider
            toggleRow(icon: "clock", title: "Include Timestamps", isOn: $includeTimestamps)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.uiElement))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.text.opacity(0.08), lineWidth: 0.5))
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(palette.accent)
                .frame(width: 32, height: 32)

            Text(title)
                .font(AppTheme.Typography.sansBody(size: 16, weight: .medium))
                .foregroundColor(palette.text)

            Spacer()

            ThemedToggle(isOn: isOn)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var dateRangeCard: some View {
        VStack(spacing: 0) {
            datePickerRow(title: "From", selection: $startDate)
            divider
            datePickerRow(title: "To", selection: $endDate)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.uiElement))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.text.opacity(0.08), lineWidth: 0.5))
    }

    private func datePickerRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Typography.sansBody(size: 16, weight: .medium))
                .foregroundColor(palette.text)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var footerArea: some View {
        VStack(spacing: 12) {
            if isProgressVisible, let p = exportProgress {
                inlineProgressCard(progress: p)
                    .transition(.blurFade)
            }
            actionButton
        }
        .animation(.smooth(duration: 0.35), value: isProgressVisible)
    }

    private func inlineProgressCard(progress: ExportCoordinator.Progress) -> some View {
        let current = progressCurrent(progress)
        let total = progressTotal(progress)
        let fraction: Double = total > 0 ? min(1, max(0, Double(current) / Double(total))) : 0

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(palette.text.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Exported \(current) / \(total)")
                    .font(AppTheme.Typography.sansBody(size: 14, weight: .semibold))
                    .foregroundColor(palette.text)
                Text(progressPhase(progress))
                    .font(AppTheme.Typography.sansBody(size: 12, weight: .regular))
                    .foregroundColor(palette.text.opacity(0.55))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.uiElement))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.text.opacity(0.08), lineWidth: 0.5))
    }

    private var actionButton: some View {
        Button {
            if isRunning {
                cancelExport()
            } else {
                startExport()
            }
        } label: {
            ZStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Export")
                        .font(AppTheme.Typography.sansBody(size: 16, weight: .bold))
                }
                .opacity(isRunning ? 0 : 1)

                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Cancel")
                        .font(AppTheme.Typography.sansBody(size: 16, weight: .bold))
                }
                .opacity(isRunning ? 1 : 0)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isRunning ? AppTheme.Colors.danger : palette.accent)
            )
            .animation(.easeInOut(duration: 0.15), value: isRunning)
        }
        .buttonStyle(.plain)
        .disabled(!isRunning && makeRequestScope() == nil)
        .opacity((!isRunning && makeRequestScope() == nil) ? 0.5 : 1)
    }

    private func startExport() {
        guard let scopeValue = makeRequestScope() else { return }
        let req = ExportCoordinator.Request(
            scope: scopeValue,
            toggles: .init(
                includeAnnotations: includeAnnotations,
                includeAISummaries: includeAISummaries,
                includeEmbeddings: includeEmbeddings,
                includeTimestamps: includeTimestamps
            )
        )
        activeTask?.cancel()
        gateTask?.cancel()
        progressGateVisible = false

        gateTask = Task {
            try? await Task.sleep(nanoseconds: Self.progressGateDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run { progressGateVisible = true }
        }

        activeTask = Task {
            for await progress in await ExportCoordinator.shared.run(req) {
                await MainActor.run {
                    if case .writing(_, let t) = progress { lastTotal = t }
                    exportProgress = progress
                }
                switch progress {
                case .finished(let url):
                    await MainActor.run { shareItem = ShareItem(url: url) }
                case .cancelled, .failed:
                    gateTask?.cancel()
                    await MainActor.run { progressGateVisible = false }
                default:
                    break
                }
            }
        }
    }

    private func cancelExport() {
        activeTask?.cancel()
        activeTask = nil
        gateTask?.cancel()
        gateTask = nil
        progressGateVisible = false
        exportProgress = nil
    }

    private func makeRequestScope() -> ExportCoordinator.Request.Scope? {
        if let fixed = fixedCoordinatorScope { return fixed }
        switch scope {
        case .wholeBase: return .wholeBase
        case .dateRange: return .dateRange(start: startDate, end: endDate)
        case .topic, .site, .page: return nil
        }
    }

    private func progressCurrent(_ p: ExportCoordinator.Progress) -> Int {
        switch p {
        case .writing(let c, _): return c
        case .zipping, .finished: return lastTotal
        default: return 0
        }
    }

    private func progressTotal(_ p: ExportCoordinator.Progress) -> Int {
        switch p {
        case .writing(_, let t): return t
        case .zipping, .finished: return lastTotal
        default: return max(1, lastTotal)
        }
    }

    private func progressPhase(_ p: ExportCoordinator.Progress) -> String {
        switch p {
        case .fetching: return "Preparing…"
        case .writing: return "Writing…"
        case .zipping: return "Zipping…"
        case .finished: return "Done"
        case .cancelled: return "Cancelled"
        case .failed(let msg): return msg
        }
    }

    private struct ShareItem: Identifiable {
        var id: URL { url }
        let url: URL
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct BlurFadeModifier: ViewModifier {
    let visible: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: visible ? 0 : 10)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.96, anchor: .bottom)
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurFadeModifier(visible: false),
            identity: BlurFadeModifier(visible: true)
        )
    }
}
