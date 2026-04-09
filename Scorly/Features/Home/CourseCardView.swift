//
// CourseCardView.swift
// Renders a single course card as a simple Wallet-style course surface.
//

import SwiftUI

struct CourseCardView: View {
    let course: Course
    let isSelected: Bool
    var onInfo: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Base gradient
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(cardGradient)

            // Subtle top-leading sheen
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.06), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Bottom edge vignette
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 80)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))

            // Border
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)
                        .lineLimit(2)

                    Text(course.location)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    HStack(spacing: 0) {
                        cardMetric(value: "\(course.averageScore)", label: "Avg Score")
                        Rectangle().fill(.white.opacity(0.20)).frame(width: 1, height: 26).padding(.trailing, 14)
                        cardMetric(value: "\(course.bestScore)", label: "Best Score")
                        Rectangle().fill(.white.opacity(0.20)).frame(width: 1, height: 26).padding(.trailing, 14)
                        cardMetric(value: "\(course.roundsPlayed)", label: "Rounds")
                    }
                    .opacity(isSelected && course.roundsPlayed > 0 ? 1 : 0)

                    Spacer(minLength: 0)

                    if let tee = displayTee {
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(String(format: "%.1f", tee.rating))
                                .font(Theme.Typography.bodySemibold)
                                .foregroundStyle(.white)
                            Text(" / \(tee.slope)")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.white.opacity(0.70))
                        }
                    }
                }
            }
            .padding(Theme.Spacing.xl)

            // Info button — top right, only when selected
            if let onInfo {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onInfo) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(ScorlyPressStyle())
                    }
                    Spacer()
                }
                .padding(14)
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 212)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.08), radius: isSelected ? 3 : 2, y: isSelected ? 2 : 1)
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.12), radius: isSelected ? 20 : 12, y: isSelected ? 12 : 6)
        .shadow(color: .black.opacity(isSelected ? 0.14 : 0.08), radius: isSelected ? 50 : 28, y: isSelected ? 28 : 16)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: course.accentColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func cardMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.trailing, 14)
    }

    private var displayTee: CourseTee? {
        if course.tees.count > 1 {
            return course.tees[1]
        }
        return course.tees.first
    }
}
