import SwiftUI

// MARK: - ScorlyCard

struct ScorlyCard<Content: View>: View {
    var padding: CGFloat = Theme.Spacing.cardPadding
    var radius: CGFloat = Theme.Radius.lg
    var shadow: ShadowStyle = Theme.Shadow.subtle
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.Colors.whisperBorder, lineWidth: 1)
            )
            .themeShadow(shadow)
    }
}

// MARK: - ScorlyButton

struct ScorlyButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
    }

    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var isFullWidth: Bool = true
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(Theme.Typography.bodySemibold)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 50)
            .padding(.horizontal, Theme.Spacing.lg)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(borderOverlay)
        }
        .buttonStyle(ScorlyPressStyle())
        .opacity(isDisabled ? 0.4 : 1.0)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: Theme.Colors.accent
        case .ghost: Theme.Colors.textSecondary
        case .destructive: .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: Theme.Colors.accent
        case .secondary: Theme.Colors.accent.opacity(0.08)
        case .ghost: .clear
        case .destructive: Theme.Colors.error
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .secondary:
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1)
        case .ghost:
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.divider, lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - Press Button Style

struct ScorlyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Animation.pressScale : 1.0)
            .animation(Theme.Animation.snappy, value: configuration.isPressed)
    }
}

// MARK: - ScorlyBadge

struct ScorlyBadge: View {
    let text: String
    var color: Color = Theme.Colors.accent
    var size: Size = .regular

    enum Size {
        case small, regular, large
    }

    var body: some View {
        Text(text)
            .font(fontSize)
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fontSize: Font {
        switch size {
        case .small: Theme.Typography.captionSmall
        case .regular: Theme.Typography.caption
        case .large: Theme.Typography.bodySemibold
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: Theme.Spacing.xxs + 2
        case .regular: Theme.Spacing.xs
        case .large: Theme.Spacing.sm
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: Theme.Spacing.xxxs
        case .regular: Theme.Spacing.xxs
        case .large: Theme.Spacing.xs - 2
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: Theme.Radius.sm - 2
        case .regular: Theme.Radius.sm
        case .large: Theme.Radius.md - 2
        }
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text(title)
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            Spacer()
            if let trailing {
                trailing
            }
        }
    }
}

// MARK: - ScorlyDivider

struct ScorlyDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colors.divider)
            .frame(height: 1)
    }
}

// MARK: - Animated Number

struct AnimatedNumber: View {
    let value: Int
    var font: Font = Theme.Typography.monoDisplay
    var color: Color = Theme.Colors.textPrimary

    var body: some View {
        Text("\(value)")
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(value)))
            .animation(Theme.Animation.bouncy, value: value)
    }
}

// MARK: - Score Badge (contextual color)

struct ScoreVsParBadge: View {
    let scoreVsPar: Int
    var size: ScorlyBadge.Size = .regular

    var body: some View {
        ScorlyBadge(
            text: scoreVsPar == 0 ? "E" : (scoreVsPar > 0 ? "+\(scoreVsPar)" : "\(scoreVsPar)"),
            color: scoreColor,
            size: size
        )
    }

    private var scoreColor: Color {
        if scoreVsPar < 0 { return Theme.Colors.underPar }
        if scoreVsPar > 0 { return Theme.Colors.overPar }
        return Theme.Colors.evenPar
    }
}
