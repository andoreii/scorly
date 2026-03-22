//
// CompletedRound.swift
// Data model for a fully completed golf round.
//

import SwiftUI

struct CompletedRound: Identifiable {
    let id: UUID
    let databaseId: Int?
    let courseName: String
    let courseLocation: String
    let date: Date
    let par: Int
    let totalScore: Int
    let tee: String
    let courseRating: Double
    let slope: Int
    let conditions: String
    let temperature: Int?
    let holesPlayed: Int
    let holeStats: [HoleStat]
    let holes: [CourseHole]
    let roundType: String
    let format: String
    let transport: String
    let notes: String?

    var scoreVsPar: Int { totalScore - par }

    var scoreVsParText: String {
        if scoreVsPar == 0 { return "E" }
        return scoreVsPar > 0 ? "+\(scoreVsPar)" : "\(scoreVsPar)"
    }

    var scoreColor: Color {
        if scoreVsPar < 0  { return Color(red: 0.353, green: 0.620, blue: 0.365) }
        if scoreVsPar > 8  { return Color(red: 0.70, green: 0.15, blue: 0.15) }
        return .black
    }

    var totalPutts: Int {
        holeStats.reduce(0) { $0 + $1.putts }
    }

    var greensInReg: Int {
        zip(holeStats, holes).filter { $0.greenInReg(par: $1.par) }.count
    }

    var fairwaysHit: Int {
        zip(holeStats, holes).filter { $0.fairwayInReg(par: $1.par) }.count
    }

    var fairwaysApplicable: Int {
        holes.filter { $0.par > 3 }.count
    }

    var frontNineScore: Int {
        Array(holeStats.prefix(min(9, holeStats.count))).reduce(0) { $0 + $1.strokes }
    }

    var backNineScore: Int {
        guard holeStats.count > 9 else { return 0 }
        return Array(holeStats.suffix(from: 9)).reduce(0) { $0 + $1.strokes }
    }

    var frontNinePar: Int {
        Array(holes.prefix(min(9, holes.count))).reduce(0) { $0 + $1.par }
    }

    var backNinePar: Int {
        guard holes.count > 9 else { return 0 }
        return Array(holes.suffix(from: 9)).reduce(0) { $0 + $1.par }
    }

    var hasBackNine: Bool { holesPlayed == 18 }

    // WHS score differential: (113 / slope) × (score − courseRating)
    var scoreDifferential: Double {
        (113.0 / Double(slope)) * (Double(totalScore) - courseRating)
    }
}

// MARK: – Supabase conversion

extension CompletedRound {
    init(from row: RoundRow, course: CourseRow) {
        let sortedTees = (course.tees ?? []).sorted { $0.teeId < $1.teeId }
        let sortedHoles = (course.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }
        let matchedTee = sortedTees.first { $0.teeId == row.teeId }

        let stats = (row.holeStats ?? []).sorted { $0.holeNumber < $1.holeNumber }

        self.id = UUID()
        self.databaseId = row.roundId
        self.courseName = course.courseName
        self.courseLocation = course.location ?? ""

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.date = dateFormatter.date(from: row.datePlayed) ?? Date()

        self.par = sortedHoles.reduce(0) { $0 + $1.par }
        self.totalScore = stats.isEmpty ? (row.totalScore ?? 0) : stats.reduce(0) { $0 + $1.strokes }
        self.tee = matchedTee?.teeName ?? ""
        self.courseRating = matchedTee?.courseRating ?? 0
        self.slope = Int(matchedTee?.slopeRating ?? 113)
        self.conditions = row.conditions ?? ""
        self.temperature = row.temperature
        self.holesPlayed = row.holesPlayed == "18" ? 18 : 9
        self.roundType = row.roundType ?? ""
        self.format = row.roundFormat ?? "Stroke"
        self.transport = row.walkingVsRiding ?? ""
        self.notes = row.notes

        self.holeStats = stats.map { s in
            var h = HoleStat(strokes: s.strokes)
            h.putts = s.putts
            h.teeShot = s.teeShot
            h.approach = s.approach
            h.teeClub = s.teeClub ?? ""
            h.approachClub = s.approachClub ?? ""
            h.penaltyStrokes = s.penaltyStrokes
            h.upAndDownSuccess = s.upAndDownSuccess ?? false
            h.sandSaveSuccess = s.sandSaveSuccess ?? false
            return h
        }

        self.holes = sortedHoles.map { hole in
            let yardages = sortedTees.map { tee in
                tee.teeHoles?.first { $0.holeNumber == hole.holeNumber }?.yardage ?? 0
            }
            return CourseHole(
                number: hole.holeNumber,
                par: hole.par,
                handicap: hole.holeHandicapIndex ?? 0,
                yardages: yardages.isEmpty ? [0] : yardages
            )
        }
    }
}

// MARK: – Handicap Index (WHS)

extension CompletedRound {
    /// Returns a WHS Handicap Index (rounded down to 1 decimal) from an array of rounds,
    /// or nil if fewer than 3 rounds are available.
    static func handicapIndex(from rounds: [CompletedRound]) -> Double? {
        let diffs = rounds.map(\.scoreDifferential).sorted()
        guard diffs.count >= 3 else { return nil }

        let countToUse: Int
        switch diffs.count {
        case 3...5:  countToUse = 1
        case 6...8:  countToUse = 2
        case 9...11: countToUse = 3
        case 12...14: countToUse = 4
        case 15...16: countToUse = 5
        case 17...18: countToUse = 6
        case 19:     countToUse = 7
        default:     countToUse = 8   // 20+
        }

        let avg = diffs.prefix(countToUse).reduce(0, +) / Double(countToUse)
        let raw = avg * 0.96
        return (raw * 10).rounded(.down) / 10
    }
}
