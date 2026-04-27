import SwiftUI

private struct HapticTriggerModifier<T: Equatable>: ViewModifier {
    let event: HapticsEvent
    let trigger: T

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { _, _ in
            Haptics.fire(event)
        }
    }
}

extension View {
    func haptic<T: Equatable>(_ event: HapticsEvent, trigger: T) -> some View {
        modifier(HapticTriggerModifier(event: event, trigger: trigger))
    }
}
