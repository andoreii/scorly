//
// SettingsView.swift
// Settings screen — account preferences and sign out.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    ScorlyButton(
                        title: isSigningOut ? "Signing Out..." : "Sign Out",
                        icon: "rectangle.portrait.and.arrow.right",
                        style: .destructive,
                        isDisabled: isSigningOut
                    ) {
                        isSigningOut = true
                        Task {
                            try? await auth.signOut()
                            isSigningOut = false
                            dismiss()
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.pageHorizontal)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.bodySemibold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .buttonStyle(ScorlyPressStyle())
                }
            }
        }
    }
}
