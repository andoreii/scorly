import SwiftUI

// MARK: - Design Tokens

enum Theme {

    // MARK: - Colors

    enum Colors {
        // Primary
        static let accent = Color(hex: 0x0B1215)
        static let accentLight = Color(hex: 0x191919)

        // Surfaces
        static let canvas = Color(hex: 0xF9FAFB)
        static let surface = Color.white

        // Text
        static let textPrimary = Color(hex: 0x18181B)
        static let textSecondary = Color(hex: 0x71717A)
        static let textTertiary = Color(hex: 0x94A3B8)

        // Semantic
        static let success = Color(hex: 0x2A9D8F)
        static let warning = Color(hex: 0xE9A23B)
        static let error = Color(hex: 0xC1544E)

        // Golf-specific
        static let bunker = Color(hex: 0xC4A663)
        static let water = Color(hex: 0x4A90D9)

        // Borders & Shadows
        static let whisperBorder = Color(hex: 0xE2E8F0).opacity(0.5)
        static let divider = Color(hex: 0xE2E8F0)

        // Score context
        static let underPar = success
        static let overPar = error
        static let evenPar = textSecondary

        // Radar chart
        static let scoring = textPrimary
        static let driving = Color(hex: 0x4A90D9)
        static let approach = success
        static let shortGame = bunker
        static let putting = Color(hex: 0x6366A0)
        static let trouble = error
    }

    // MARK: - Typography

    enum Typography {
        // Display — hero scores, large numbers
        static let display = Font.system(size: 48, weight: .bold, design: .default)
        static let displayMono = Font.system(size: 48, weight: .bold, design: .monospaced)

        // Large title — screen headers
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .default)

        // Title — section headers
        static let title = Font.system(size: 22, weight: .semibold, design: .default)
        static let title2 = Font.system(size: 18, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 16, weight: .semibold, design: .default)

        // Body — main content
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let bodySemibold = Font.system(size: 15, weight: .semibold, design: .default)

        // Caption — labels, metadata
        static let caption = Font.system(size: 13, weight: .medium, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .medium, design: .default)

        // Mono — numeric values, stats
        static let mono = Font.system(size: 15, weight: .medium, design: .monospaced)
        static let monoLarge = Font.system(size: 22, weight: .bold, design: .monospaced)
        static let monoDisplay = Font.system(size: 38, weight: .bold, design: .monospaced)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
        static let huge: CGFloat = 48

        /// Standard horizontal page margin
        static let pageHorizontal: CGFloat = 20
        /// Standard card internal padding
        static let cardPadding: CGFloat = 18
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Shadows

    enum Shadow {
        static let subtle = ShadowStyle(color: .black.opacity(0.04), radius: 8, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 16, y: 6)
        static let prominent = ShadowStyle(color: .black.opacity(0.12), radius: 24, y: 10)
        static let glow = ShadowStyle(color: .black.opacity(0.18), radius: 20, y: 8)
    }

    // MARK: - Animation

    enum Animation {
        /// Buttons, toggles, small taps
        static let snappy = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.82)
        /// Screen transitions, sheets
        static let smooth = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.78)
        /// Score changes, card reveals, celebrations
        static let bouncy = SwiftUI.Animation.spring(response: 0.40, dampingFraction: 0.68)
        /// Background elements, subtle shifts
        static let gentle = SwiftUI.Animation.spring(response: 0.50, dampingFraction: 0.85)
        /// Tab content entering after a swipe settles
        static let tabEnter = SwiftUI.Animation.spring(response: 0.42, dampingFraction: 0.84)
        /// Tab content fading away as focus shifts elsewhere
        static let tabExit = SwiftUI.Animation.easeOut(duration: 0.18)

        /// Stagger delay per item for list/grid reveals
        static let staggerDelay: Double = 0.05

        /// Button press scale
        static let pressScale: CGFloat = 0.96
        /// Card appear scale
        static let appearScale: CGFloat = 0.95
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
    var x: CGFloat = 0
}

// MARK: - Tab Motion

@MainActor
@Observable
final class TabMotionCoordinator {
    private(set) var activeTab: Int? = nil
    private var transitionTask: Task<Void, Never>?

    func prime(with tab: Int) {
        transition(to: tab, delay: 0.06)
    }

    func transition(to tab: Int, delay: Double = 0.14) {
        transitionTask?.cancel()
        activeTab = nil

        transitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            activeTab = tab
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers

extension View {
    func themeShadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }

    /// Staggered appear animation for list items
    func staggeredAppear(index: Int, isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : Theme.Animation.appearScale)
            .animation(
                Theme.Animation.smooth.delay(Double(index) * Theme.Animation.staggerDelay),
                value: isVisible
            )
    }

    /// Press effect for interactive elements
    func pressEffect(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? Theme.Animation.pressScale : 1.0)
            .animation(Theme.Animation.snappy, value: isPressed)
    }

    /// Replays a consistent fade/slide reveal whenever the owning tab becomes active.
    func tabReveal(tab: Int, order: Int = 0, isEnabled: Bool = true) -> some View {
        modifier(TabReveal(tab: tab, order: order, isEnabled: isEnabled))
    }

    /// Sequenced fade/slide visibility for coordinated mode swaps inside a screen.
    func sequencedVisibility(
        index: Int,
        isVisible: Bool,
        hiddenOffset: CGFloat = 20,
        hiddenScale: CGFloat = 0.985,
        enterAnimation: SwiftUI.Animation = Theme.Animation.bouncy,
        exitAnimation: SwiftUI.Animation = Theme.Animation.tabExit,
        enterStagger: Double = Theme.Animation.staggerDelay,
        exitStagger: Double = 0.035
    ) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : hiddenOffset)
            .scaleEffect(isVisible ? 1 : hiddenScale, anchor: .top)
            .animation(
                isVisible
                    ? enterAnimation.delay(Double(index) * enterStagger)
                    : exitAnimation.delay(Double(index) * exitStagger),
                value: isVisible
            )
    }
}

// MARK: - Fade Slide In Modifier

/// Consistent fade + slide-up entrance used across all tabs.
/// Offset slides from 18pt below, opacity from 0, with a bouncy spring.
struct FadeSlideIn: ViewModifier {
    let appeared: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(Theme.Animation.bouncy.delay(delay), value: appeared)
    }
}

private struct TabReveal: ViewModifier {
    @Environment(TabMotionCoordinator.self) private var tabMotion

    let tab: Int
    let order: Int
    let isEnabled: Bool

    private var isVisible: Bool {
        isEnabled && tabMotion.activeTab == tab
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 22)
            .scaleEffect(isVisible ? 1 : 0.985, anchor: .top)
            .animation(
                isVisible
                    ? Theme.Animation.tabEnter.delay(Double(order) * Theme.Animation.staggerDelay)
                    : Theme.Animation.tabExit,
                value: isVisible
            )
    }
}
