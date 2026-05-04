import SwiftUI

struct ExportProgressModal: View {
    var current: Int
    var total: Int
    var phase: String
    var onCancel: () -> Void

    @Environment(\.palette) private var palette

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(total)))
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                progressRing
                VStack(spacing: 4) {
                    Text("Exported \(current) / \(total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(palette.text)
                    Text(phase)
                        .font(.footnote)
                        .foregroundColor(palette.text.opacity(0.55))
                }
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.Colors.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.Colors.danger.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 280)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.uiElement))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(palette.text.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.2), radius: 30)
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(palette.text.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: fraction)
            Text("\(Int(fraction * 100))%")
                .font(.system(.callout, design: .monospaced).weight(.bold))
                .foregroundColor(palette.text)
                .monospacedDigit()
        }
        .frame(width: 80, height: 80)
    }
}
