//
// ContentView.swift
// Root container — swipeable page layout with subtle dot indicator.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var auth
    @StateObject private var roundStore = RoundStore()
    @State private var selectedTab = LaunchOptions.initialTab

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView()
            } else if auth.isSignedIn {
                mainContent
            } else {
                AuthView()
            }
        }
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

            // Subtle page indicator — floats above home indicator
            pageIndicator
                .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: roundStore.pendingDismissToHome) { _, triggered in
            guard triggered else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    selectedTab = 0
                }
                roundStore.pendingDismissToHome = false
            }
        }
        .onChange(of: roundStore.pendingDismissToRounds) { _, triggered in
            guard triggered else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
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
                    .fill(i == selectedTab ? Color.black : Color.black.opacity(0.15))
                    .frame(
                        width: i == selectedTab ? 20 : 6,
                        height: 6
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedTab)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
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
