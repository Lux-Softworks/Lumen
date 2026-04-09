import SwiftUI

struct ThemedToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.smooth(duration: 0.25)) {
                isOn.toggle()
            }
        }) {
            ZStack {
                Capsule()
                    .fill(isOn ? AppTheme.Colors.accent : AppTheme.Colors.text.opacity(0.1))
                    .frame(width: 48, height: 28)

                Circle()
                    .fill(.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: isOn ? 10 : -10)
            }
        }
        .buttonStyle(.plain)
    }
}
