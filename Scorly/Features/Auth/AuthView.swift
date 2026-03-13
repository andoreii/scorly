//
// AuthView.swift
// Simple sign-in / sign-up screen shown when no session exists.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo area
            VStack(spacing: 12) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(.black)

                Text("Golf Statistics")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(isSignUp ? "Create your account" : "Sign in to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 48)

            // Form
            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
            }

            // Action button
            Button {
                submit()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Toggle mode
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    errorMessage = nil
                }
            } label: {
                Text(isSignUp ? "Already have an account? **Sign in**" : "Don't have an account? **Sign up**")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
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
