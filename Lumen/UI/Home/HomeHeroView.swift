import SwiftUI

struct HomeHeroView: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .body) private var sparkleSize: CGFloat = 100
    @ScaledMetric(relativeTo: .body) private var taglineSize: CGFloat = 18

    @State private var currentTagline: String = ""
    @State private var isBreathing: Bool = false
    @State private var isTranslating: Bool = false
    @State private var hasAppeared: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            sparkleIcon
            tagline
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 120)
        .offset(y: isTranslating ? -6 : 6)
        .animation(
            reduceMotion
                ? .none
                : .easeInOut(duration: 4.5).repeatForever(autoreverses: true),
            value: isTranslating
        )
        .opacity(hasAppeared ? 1 : 0)
        .animation(
            reduceMotion ? .none : .easeOut(duration: 0.5).delay(0.25),
            value: hasAppeared
        )
        .allowsHitTesting(false)
        .onAppear {
            currentTagline = Self.pickTagline(at: Date())
            hasAppeared = true
            guard !reduceMotion else { return }
            isBreathing = true
        }
    }

    private var sparkleIcon: some View {
        Image(systemName: "sparkle")
            .font(.system(size: sparkleSize, weight: .regular))
            .foregroundStyle(
                LinearGradient(
                    colors: [palette.accent, palette.secondaryAccent],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: palette.accent.opacity(0.4), radius: 24)
            .opacity(isBreathing ? 1.0 : 0.7)
            .animation(
                reduceMotion
                    ? .default
                    : .easeInOut(duration: 3.5).repeatForever(autoreverses: true),
                value: isBreathing
            )
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var tagline: some View {
        Text(currentTagline)
            .font(AppTheme.Typography.sansBody(size: taglineSize, weight: .semibold))
            .foregroundColor(palette.text.opacity(0.6))
            .multilineTextAlignment(.center)
            .dynamicTypeSize(.xSmall ... .accessibility3)
            .transition(.opacity.animation(.easeOut(duration: 0.35)))
            .id(currentTagline)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    enum TimeBucket {
        case morning, midday, afternoon, evening, late

        static func forHour(_ h: Int) -> TimeBucket {
            switch h {
            case 5..<11: return .morning
            case 11..<14: return .midday
            case 14..<18: return .afternoon
            case 18..<22: return .evening
            default: return .late
            }
        }

        var pool: [String] {
            switch self {
            case .morning:   return ["good morning, let's learn.", "fresh start.", "today's first idea?"]
            case .midday:    return ["ready to dig in?", "midday momentum.", "one more page."]
            case .afternoon: return ["stay curious.", "what's next?", "keep going."]
            case .evening:   return ["tonight's rabbit hole?", "wind down with an idea.", "read something good."]
            case .late:      return ["still up?", "one more before bed.", "quiet hours, loud ideas."]
            }
        }
    }

    static func pickTagline(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let bucket = TimeBucket.forHour(hour)
        return bucket.pool.randomElement() ?? ""
    }
}
