import UIKit

@MainActor
enum Haptics {
    private static var lastFiredAt: [HapticsEvent: CFTimeInterval] = [:]
    private static let throttleWindow: CFTimeInterval = 0.09

    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGen = UISelectionFeedbackGenerator()
    private static let notificationGen = UINotificationFeedbackGenerator()

    static var clock: () -> CFTimeInterval = { CACurrentMediaTime() }
    static var modeProvider: () -> HapticsMode = { BrowserSettings.shared.hapticsMode }
    static var fireImpl: ((HapticsEvent) -> Void)? = nil

    static func prepareAll() {
        softGen.prepare(); rigidGen.prepare(); lightGen.prepare()
        mediumGen.prepare(); heavyGen.prepare()
        selectionGen.prepare(); notificationGen.prepare()
    }

    static func fire(_ event: HapticsEvent) {
        let mode = modeProvider()
        guard mode != .off, event.minMode.rank <= mode.rank else { return }

        if !event.bypassesThrottle {
            let now = clock()
            if let last = lastFiredAt[event], now - last < throttleWindow {
                return
            }
            lastFiredAt[event] = now
        }

        if let custom = fireImpl {
            custom(event)
            return
        }

        switch event.generator {
        case .impact(let style, let intensity):
            let gen = generator(for: style)
            gen.impactOccurred(intensity: intensity)
            gen.prepare()
        case .selection:
            selectionGen.selectionChanged()
            selectionGen.prepare()
        case .notification(let type):
            notificationGen.notificationOccurred(type)
            notificationGen.prepare()
        }
    }

    private static func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .soft: return softGen
        case .rigid: return rigidGen
        case .light: return lightGen
        case .medium: return mediumGen
        case .heavy: return heavyGen
        @unknown default: return mediumGen
        }
    }

    static func resetForTests() {
        lastFiredAt.removeAll()
        clock = { CACurrentMediaTime() }
        modeProvider = { BrowserSettings.shared.hapticsMode }
        fireImpl = nil
    }
}
