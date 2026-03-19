//
// RoundStore.swift
// Shared observable store — tracks the active round and persists it to UserDefaults.
//

import SwiftUI

// MARK: - Persistent snapshot (Codable)

private struct SavedRound: Codable {
    var courseName: String       // identifies the course
    var courseDatabaseId: Int?   // Supabase course_id
    var datePlayed: Date
    var holesOption: RoundSetupView.HolesOption
    var teeIndex: Int
    var currentHoleIndex: Int
    var holeStats: [HoleStat]
    var notes: String
    var conditions: [String]
    var temperature: Int?
    var roundType: String
    var roundFormat: String
    var transport: String
    var mentalState: Int
    var roundExternalId: String
    var startedAt: Date
}

// MARK: - In-memory active round

struct ActiveRoundData {
    var course: Course
    var datePlayed: Date
    var holes: [CourseHole]
    var holesOption: RoundSetupView.HolesOption
    var teeIndex: Int
    var currentHoleIndex: Int = 0
    var holeStats: [HoleStat] = []
    var notes: String = ""
    var conditions: [String] = []
    var temperature: Int? = nil
    var roundType: String = ""
    var roundFormat: String = ""
    var transport: String = ""
    var mentalState: Int = 5
    var roundExternalId: String = UUID().uuidString
    var startedAt: Date = .now

    var currentHole: CourseHole { holes[currentHoleIndex] }

    var playedCount: Int {
        holeStats.filter { $0.teeShot != nil || $0.putts > 0 }.count
    }

    var scoreVsPar: Int {
        holeStats.enumerated().reduce(0) { sum, pair in
            sum + pair.element.strokes - holes[pair.offset].par
        }
    }
}

// MARK: - Store

class RoundStore: ObservableObject {
    @Published var activeRound: ActiveRoundData? = nil

    /// Set to true to trigger every parent layer (cover + tab) to dismiss back to Home.
    @Published var pendingDismissToHome = false

    /// Set to true to dismiss covers and navigate to the Rounds tab after finishing.
    @Published var pendingDismissToRounds = false

    private static let saveKey = "com.golf.savedRound"

    init() {
        // Try to restore in-progress round from UserDefaults + Supabase course data
        Task { @MainActor in
            await loadSavedRound()
        }
    }

    // MARK: Round lifecycle

    func startRound(course: Course,
                    datePlayed: Date = .now,
                    holes: [CourseHole],
                    holesOption: RoundSetupView.HolesOption,
                    teeIndex: Int,
                    notes: String = "",
                    conditions: [String] = [],
                    temperature: Int? = nil,
                    roundType: String = "",
                    roundFormat: String = "",
                    transport: String = "",
                    mentalState: Int = 5) {
        guard activeRound == nil else { return }
        activeRound = ActiveRoundData(
            course: course,
            datePlayed: datePlayed,
            holes: holes,
            holesOption: holesOption,
            teeIndex: teeIndex,
            holeStats: holes.map { HoleStat(strokes: $0.par) },
            notes: notes,
            conditions: conditions,
            temperature: temperature,
            roundType: roundType,
            roundFormat: roundFormat,
            transport: transport,
            mentalState: mentalState
        )
        saveActiveRound()
    }

    func update(currentHoleIndex: Int, holeStats: [HoleStat]) {
        activeRound?.currentHoleIndex = currentHoleIndex
        activeRound?.holeStats = holeStats
        saveActiveRound()
    }

    func updateNotes(_ notes: String) {
        activeRound?.notes = notes
        saveActiveRound()
    }

    /// Persist and navigate back to the home screen.
    func saveAndExit() {
        saveActiveRound()
        pendingDismissToHome = true
    }

    /// Mark the round as fully finished — saves to Supabase, clears everything, navigates home.
    func finishRound() {
        if let round = activeRound {
            Task { await saveToSupabase(round) }
        }
        activeRound = nil
        clearSavedRound()
        pendingDismissToHome = true
    }

    /// Mark the round as fully finished — saves to Supabase, clears everything, navigates to Rounds tab.
    func finishRoundToRounds() {
        if let round = activeRound {
            Task { await saveToSupabase(round) }
        }
        activeRound = nil
        clearSavedRound()
        pendingDismissToRounds = true
    }

    /// Silently delete the round with no navigation (caller is already on the home screen).
    func deleteRound() {
        activeRound = nil
        clearSavedRound()
    }

    /// Delete the in-progress round and dismiss back to Home without saving it.
    func deleteRoundAndExit() {
        deleteRound()
        pendingDismissToHome = true
    }

    // MARK: Persistence

    private func saveActiveRound() {
        guard let round = activeRound else { return }

        let snapshot = SavedRound(
            courseName: round.course.name,
            courseDatabaseId: round.course.databaseId,
            datePlayed: round.datePlayed,
            holesOption: round.holesOption,
            teeIndex: round.teeIndex,
            currentHoleIndex: round.currentHoleIndex,
            holeStats: round.holeStats,
            notes: round.notes,
            conditions: round.conditions,
            temperature: round.temperature,
            roundType: round.roundType,
            roundFormat: round.roundFormat,
            transport: round.transport,
            mentalState: round.mentalState,
            roundExternalId: round.roundExternalId,
            startedAt: round.startedAt
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    private func loadSavedRound() async {
        guard
            let data = UserDefaults.standard.data(forKey: Self.saveKey),
            let snapshot = try? JSONDecoder().decode(SavedRound.self, from: data)
        else { return }

        // Fetch courses from Supabase to find the saved course
        var course: Course?
        if let dbId = snapshot.courseDatabaseId {
            if let courseRows = try? await DataService.shared.fetchCourses() {
                if let row = courseRows.first(where: { $0.courseId == dbId }) {
                    course = Course(from: row)
                }
            }
        }

        guard let course else {
            clearSavedRound()
            return
        }

        let allHoles = course.holes
        let holes: [CourseHole]
        switch snapshot.holesOption {
        case .front9: holes = Array(allHoles.prefix(9))
        case .back9:  holes = Array(allHoles.suffix(9))
        case .full18: holes = allHoles
        }

        guard snapshot.holeStats.count == holes.count else {
            clearSavedRound()
            return
        }

        activeRound = ActiveRoundData(
            course: course,
            datePlayed: snapshot.datePlayed,
            holes: holes,
            holesOption: snapshot.holesOption,
            teeIndex: snapshot.teeIndex,
            currentHoleIndex: min(snapshot.currentHoleIndex, holes.count - 1),
            holeStats: snapshot.holeStats,
            notes: snapshot.notes,
            conditions: snapshot.conditions,
            temperature: snapshot.temperature,
            roundType: snapshot.roundType,
            roundFormat: snapshot.roundFormat,
            transport: snapshot.transport,
            mentalState: snapshot.mentalState,
            roundExternalId: snapshot.roundExternalId,
            startedAt: snapshot.startedAt
        )
    }

    private func clearSavedRound() {
        UserDefaults.standard.removeObject(forKey: Self.saveKey)
    }

    // MARK: Supabase

    @MainActor
    private func saveToSupabase(_ round: ActiveRoundData) async {
        guard let courseId = round.course.databaseId else { return }

        let teeId = round.course.tees[safe: round.teeIndex]?.databaseId
        let courseRating = round.course.tees[safe: round.teeIndex]?.rating ?? 0
        let slope = round.course.tees[safe: round.teeIndex]?.slope ?? 113
        let holesPlayed: String
        switch round.holesOption {
        case .front9: holesPlayed = "Front 9"
        case .back9:  holesPlayed = "Back 9"
        case .full18: holesPlayed = "18"
        }

        let stats = zip(round.holeStats, round.holes).map { stat, hole in
            (
                holeNumber: hole.number,
                strokes: stat.strokes,
                putts: stat.putts,
                teeShot: stat.teeShot,
                approach: stat.approach,
                teeClub: stat.teeClub.isEmpty ? nil : stat.teeClub as String?,
                approachClub: stat.approachClub.isEmpty ? nil : stat.approachClub as String?,
                outOfBoundsCount: stat.outOfBoundsCount,
                penaltyStrokes: stat.penaltyStrokes,
                hazardCount: stat.hazardCount,
                greenInReg: stat.greenInReg(par: hole.par) as Bool?,
                threePutt: stat.threePutt as Bool?,
                girOpportunity: (hole.par > 3) as Bool?,
                fairwayOpportunity: (hole.par > 3) as Bool?,
                upAndDownSuccess: stat.upAndDownSuccess as Bool?,
                sandSaveSuccess: stat.sandSaveSuccess as Bool?
            )
        }

        let totalScore = round.holeStats.reduce(0) { $0 + $1.strokes }
        let whsDifferential = scoreDifferential(
            totalScore: totalScore,
            courseRating: courseRating,
            slope: slope,
            holesPlayed: holesPlayed
        )

        do {
            _ = try await DataService.shared.saveRound(
                courseId: courseId,
                teeId: teeId,
                datePlayed: round.datePlayed,
                holesPlayed: holesPlayed,
                roundType: databaseRoundType(from: round.roundType),
                roundFormat: databaseRoundFormat(from: round.roundFormat),
                conditions: round.conditions.isEmpty ? nil : round.conditions.joined(separator: ", "),
                temperature: round.temperature,
                walkingVsRiding: databaseTransport(from: round.transport),
                timeOfDay: timeOfDay(for: round.startedAt),
                mentalState: round.mentalState,
                roundExternalId: round.roundExternalId,
                notes: round.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : round.notes,
                whsDifferential: whsDifferential,
                holeStats: stats
            )
        } catch {
            print("Failed to save round to Supabase: \(error)")
        }
    }

    private func databaseRoundType(from value: String) -> String? {
        switch value {
        case RoundSetupView.RoundType.casual.rawValue:
            return "Casual"
        case RoundSetupView.RoundType.practice.rawValue:
            return "Practice"
        case RoundSetupView.RoundType.tournament.rawValue:
            return "Tournament"
        case RoundSetupView.RoundType.competitive.rawValue:
            return "Competitive"
        default:
            return value.isEmpty ? nil : value
        }
    }

    private func databaseRoundFormat(from value: String) -> String? {
        switch value {
        case RoundSetupView.RoundFormat.strokePlay.rawValue:
            return "Stroke Play"
        case RoundSetupView.RoundFormat.matchPlay.rawValue:
            return "Match Play"
        case RoundSetupView.RoundFormat.stableford.rawValue:
            return "Stableford"
        case RoundSetupView.RoundFormat.scramble.rawValue:
            return "Scramble"
        default:
            return value.isEmpty ? nil : value
        }
    }

    private func databaseTransport(from value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private func timeOfDay(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<8:
            return "Early Morning"
        case 8..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<20:
            return "Evening"
        default:
            return "Twilight"
        }
    }

    private func scoreDifferential(
        totalScore: Int,
        courseRating: Double,
        slope: Int,
        holesPlayed: String
    ) -> Double? {
        guard holesPlayed == "18", courseRating > 0, slope > 0 else { return nil }
        let raw = (113.0 / Double(slope)) * (Double(totalScore) - courseRating)
        return (raw * 10).rounded() / 10
    }
}

// Array safe subscript (used by saveToSupabase)
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
