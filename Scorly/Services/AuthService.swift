//
// AuthService.swift
// Handles Supabase authentication — sign in, sign up, session restore, and sign out.
//

import Supabase
import SwiftUI

@MainActor
@Observable
class AuthService {
    var session: Session?
    var isLoading = true

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session?.user.id }
    var userEmail: String? { session?.user.email }
    var userInitial: String {
        guard let email = session?.user.email, let first = email.first else { return "?" }
        return String(first).uppercased()
    }

    init() {
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        do {
            session = try await supabase.auth.session
        } catch {
            session = nil
        }
        isLoading = false

        // Listen for auth state changes
        for await (event, newSession) in await supabase.auth.authStateChanges {
            switch event {
            case .signedIn, .tokenRefreshed:
                session = newSession
            case .signedOut:
                session = nil
            default:
                break
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
        // Explicitly sign in after sign-up to ensure session is active
        try await supabase.auth.signIn(email: email, password: password)
        await ensureUserProfile()
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
        await ensureUserProfile()
    }

    /// Creates the users row if it doesn't exist yet (first sign-in after sign-up).
    private func ensureUserProfile() async {
        guard let uid = try? await supabase.auth.session.user.id else { return }
        do {
            // Try to fetch existing profile
            let _: UserRow = try await supabase
                .from("users")
                .select()
                .eq("id", value: uid.uuidString)
                .single()
                .execute()
                .value
        } catch {
            // Doesn't exist yet — create it
            try? await supabase
                .from("users")
                .insert(["id": uid.uuidString])
                .execute()
        }
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}
