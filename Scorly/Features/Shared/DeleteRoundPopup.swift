//
// DeleteRoundPopup.swift
// Custom centered popup for round deletion confirmation.
//

import SwiftUI

struct DeleteRoundPopup: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
                .animation(Theme.Animation.smooth, value: appeared)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.error.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.Colors.error)
                }
                .padding(.top, 28)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(Theme.Animation.bouncy.delay(0.1), value: appeared)

                Text("Delete Round?")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, Theme.Spacing.md)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(Theme.Animation.smooth.delay(0.15), value: appeared)

                Text("All progress will be permanently lost.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, 6)
                    .opacity(appeared ? 1 : 0)
                    .animation(Theme.Animation.smooth.delay(0.2), value: appeared)

                HStack(spacing: Theme.Spacing.sm) {
                    ScorlyButton(title: "Cancel", style: .ghost) { onCancel() }
                    ScorlyButton(title: "Delete", style: .destructive) { onDelete() }
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(Theme.Animation.smooth.delay(0.25), value: appeared)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .themeShadow(Theme.Shadow.prominent)
            )
            .scaleEffect(appeared ? 1 : 0.88)
            .opacity(appeared ? 1 : 0)
            .animation(Theme.Animation.smooth, value: appeared)
        }
        .onAppear {
            appeared = true
        }
    }
}
