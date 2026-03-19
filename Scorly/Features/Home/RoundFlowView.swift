//
// RoundFlowView.swift
// Single-cover wrapper that contains both round setup and round tracker.
// Eliminates the nested fullScreenCover flash when dismissing the tracker.
//

import SwiftUI

struct RoundFlowView: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore

    @State private var showingTracker = false
    @State private var datePlayed: Date = .now
    @State private var holesOption: RoundSetupView.HolesOption = .full18
    @State private var teeIndex: Int = 0
    @State private var notes = ""
    @State private var conditions: [String] = []
    @State private var temperature: Int?
    @State private var roundType = ""
    @State private var roundFormat = ""
    @State private var transport = ""
    @State private var mentalState = 5

    var body: some View {
        ZStack {
            if showingTracker {
                RoundTrackerView(
                    course: course,
                    datePlayed: datePlayed,
                    holesOption: holesOption,
                    teeIndex: teeIndex,
                    notes: notes,
                    conditions: conditions,
                    temperature: temperature,
                    roundType: roundType,
                    roundFormat: roundFormat,
                    transport: transport,
                    mentalState: mentalState
                )
                .environmentObject(roundStore)
                .transition(.identity)
            } else {
                RoundSetupView(
                    course: course,
                    onStart: { payload in
                        datePlayed = payload.datePlayed
                        holesOption = payload.holesOption
                        teeIndex = payload.teeIndex
                        notes = payload.notes
                        conditions = payload.conditions
                        temperature = payload.temperature
                        roundType = payload.roundType
                        roundFormat = payload.roundFormat
                        transport = payload.transport
                        mentalState = payload.mentalState
                        withAnimation(.none) {
                            showingTracker = true
                        }
                    }
                )
                .environmentObject(roundStore)
                .transition(.identity)
            }
        }
        .onChange(of: roundStore.pendingDismissToHome) { _, triggered in
            guard triggered else { return }
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t) { dismiss() }
        }
        .onChange(of: roundStore.pendingDismissToRounds) { _, triggered in
            guard triggered else { return }
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t) { dismiss() }
        }
    }
}
