//
// ScorlyApp.swift
// Starts the app and presents the initial home screen shell.
//

import SwiftUI
import SwiftData

@main
struct ScorlyApp: App {

    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
        .modelContainer(for: [
            LocalCourse.self,
            LocalTee.self,
            LocalHole.self,
            LocalTeeHole.self,
            LocalRound.self,
            LocalHoleStat.self,
            LocalUser.self
        ])
    }
}
