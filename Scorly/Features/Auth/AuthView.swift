//
// AuthView.swift
// Branded sign-in / sign-up screen shown when no session exists.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var appeared = false
    @State private var logoAppeared = false
    @State private var formAppeared = false

    var body: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Brand mark
                VStack(spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.accentLight, Theme.Colors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .themeShadow(Theme.Shadow.glow)

                        Text("S")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(logoAppeared ? 1 : 0.5)
                    .opacity(logoAppeared ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("Scorly")
                            .font(Theme.Typography.largeTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Track every round.")
                            .font(Theme.Typography.bodyMedium)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .opacity(logoAppeared ? 1 : 0)
                    .offset(y: logoAppeared ? 0 : 10)
                }
                .padding(.bottom, 44)

                // Form card
                VStack(spacing: 0) {
                    // Segment toggle
                    HStack(spacing: Theme.Spacing.xxs) {
                        authTab("Sign In", selected: !isSignUp) {
                            withAnimation(Theme.Animation.snappy) {
                                isSignUp = false
                                errorMessage = nil
                            }
                        }
                        authTab("Sign Up", selected: isSignUp) {
                            withAnimation(Theme.Animation.snappy) {
                                isSignUp = true
                                errorMessage = nil
                            }
                        }
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.Colors.accent.opacity(0.06))
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, 14)

                    // Fields
                    VStack(spacing: Theme.Spacing.sm) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .frame(width: 20)
                            TextField("", text: $email, prompt: Text("Email").foregroundStyle(Theme.Colors.textTertiary))
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .tint(Theme.Colors.accent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Theme.Colors.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
                        )

                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .frame(width: 20)
                            SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Theme.Colors.textTertiary))
                                .textContentType(isSignUp ? .newPassword : .password)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .tint(Theme.Colors.accent)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Theme.Colors.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    // Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(Theme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, 10)
                    }

                    // Submit button
                    Button(action: submit) {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(Theme.Typography.bodySemibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(Theme.Colors.accent)
                        )
                    }
                    .buttonStyle(ScorlyPressStyle())
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .opacity(email.isEmpty || password.isEmpty ? 0.45 : 1)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.cardPadding)
                    .padding(.bottom, Theme.Spacing.cardPadding)
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .themeShadow(Theme.Shadow.medium)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
                )
                .padding(.horizontal, Theme.Spacing.xl)
                .opacity(formAppeared ? 1 : 0)
                .offset(y: formAppeared ? 0 : 30)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(Theme.Animation.bouncy.delay(0.1)) {
                logoAppeared = true
            }
            withAnimation(Theme.Animation.smooth.delay(0.3)) {
                formAppeared = true
            }
        }
    }

    private func authTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                .animation(Theme.Animation.snappy, value: selected)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Group {
                        if selected {
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(Theme.Colors.surface)
                                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                )
                .animation(Theme.Animation.snappy, value: selected)
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isSignUp {
                    try await auth.signUp(email: email, password: password)
                } else {
                    try await auth.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
