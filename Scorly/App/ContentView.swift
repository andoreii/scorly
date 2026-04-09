//
// ContentView.swift
// Root container — swipeable page layout with subtle dot indicator.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @StateObject private var roundStore = RoundStore()
    @State private var tabMotion = TabMotionCoordinator()
    @State private var selectedTab = LaunchOptions.initialTab

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView()
                    .tint(Theme.Colors.accent)
            } else if auth.isSignedIn {
                mainContent
            } else {
                AuthView()
            }
        }
        .background(Theme.Colors.canvas)
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tag(0)

                CoursesView()
                    .tag(1)

                RoundsView()
                    .tag(2)

                StatsView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .environmentObject(roundStore)
            .environment(tabMotion)

            pageIndicator
                .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            tabMotion.prime(with: selectedTab)
        }
        .onChange(of: selectedTab) { _, newValue in
            tabMotion.transition(to: newValue)
        }
        .onChange(of: roundStore.pendingDismissToHome) { _, triggered in
            guard triggered else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(Theme.Animation.smooth) {
                    selectedTab = 0
                }
                roundStore.pendingDismissToHome = false
            }
        }
        .onChange(of: roundStore.pendingDismissToRounds) { _, triggered in
            guard triggered else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(Theme.Animation.smooth) {
                    selectedTab = 2
                }
                roundStore.pendingDismissToRounds = false
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i == selectedTab ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.15))
                    .frame(
                        width: i == selectedTab ? 20 : 6,
                        height: 6
                    )
                    .animation(Theme.Animation.snappy, value: selectedTab)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Theme.Colors.surface.opacity(0.92))
                .themeShadow(Theme.Shadow.subtle)
        )
    }
}

private enum LaunchOptions {
    static var initialTab: Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-initialTab"),
              arguments.indices.contains(flagIndex + 1),
              let value = Int(arguments[flagIndex + 1]),
              (0...3).contains(value)
        else {
            return 0
        }

        return value
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
