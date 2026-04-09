//
// Course.swift
// Defines the presentation model for course cards and detail views.
//

import SwiftUI

struct Course: Identifiable, Equatable {
    let databaseId: Int?
    let name: String
    let location: String
    let par: Int
    let accentColors: [Color]
    let roundsPlayed: Int
    let averageScore: Int
    let bestScore: Int
    let tees: [CourseTee]
    let holes: [CourseHole]

    // Championship (first) tee total yardage
    var yardage: Int { holes.reduce(0) { $0 + ($1.yardages.first ?? 0) } }

    var id: String {
        if let databaseId {
            return "course-\(databaseId)"
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return "course-\(normalizedName)|\(normalizedLocation)"
    }
}

// MARK: – Supabase conversion

extension Course {
    init(from row: CourseRow, rounds: [RoundRow] = []) {
        let sortedTees = (row.tees ?? []).sorted { $0.teeId < $1.teeId }
        let sortedHoles = (row.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }

        self.databaseId = row.courseId
        self.name = row.courseName
        self.location = row.location ?? ""
        self.par = sortedHoles.reduce(0) { $0 + $1.par }
        self.accentColors = Self.colors(for: row.colorTheme)

        self.tees = sortedTees.map { tee in
            CourseTee(
                databaseId: tee.teeId,
                name: tee.teeName,
                rating: tee.courseRating ?? 0,
                slope: Int(tee.slopeRating ?? 0)
            )
        }

        self.holes = sortedHoles.map { hole in
            let yardages = sortedTees.map { tee in
                tee.teeHoles?
                    .first { $0.holeNumber == hole.holeNumber }?
                    .yardage ?? 0
            }
            return CourseHole(
                number: hole.holeNumber,
                par: hole.par,
                handicap: hole.holeHandicapIndex ?? 0,
                yardages: yardages.isEmpty ? [0] : yardages
            )
        }

        // Stats from rounds for this course
        let courseRounds = rounds.filter { $0.courseId == row.courseId }
        self.roundsPlayed = courseRounds.count
        let scores = courseRounds.compactMap { r -> Int? in
            if let stats = r.holeStats, !stats.isEmpty {
                return stats.reduce(0) { $0 + $1.strokes }
            }
            return r.totalScore
        }
        self.averageScore = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
        self.bestScore = scores.min() ?? 0
    }

    static func colors(for theme: String?) -> [Color] {
        if let theme, let customColors = customColors(for: theme) {
            return customColors
        }

        switch theme {
        case "Forest":   return [Color(red: 0.03, green: 0.25, blue: 0.09), Color(red: 0.34, green: 0.72, blue: 0.21)]
        case "Ocean":    return [Color(red: 0.14, green: 0.35, blue: 0.72), Color(red: 0.48, green: 0.82, blue: 0.90)]
        case "Dusk":     return [Color(red: 0.40, green: 0.08, blue: 0.12), Color(red: 0.88, green: 0.33, blue: 0.34)]
        case "Desert":   return [Color(red: 0.60, green: 0.40, blue: 0.15), Color(red: 0.90, green: 0.75, blue: 0.40)]
        case "Twilight": return [Color(red: 0.38, green: 0.32, blue: 0.64), Color(red: 0.84, green: 0.78, blue: 0.96)]
        case "Slate":    return [Color(red: 0.30, green: 0.32, blue: 0.38), Color(red: 0.62, green: 0.64, blue: 0.70)]
        case "Ember":    return [Color(red: 0.70, green: 0.15, blue: 0.10), Color(red: 0.95, green: 0.50, blue: 0.20)]
        case "Mint":     return [Color(red: 0.10, green: 0.50, blue: 0.45), Color(red: 0.50, green: 0.85, blue: 0.75)]
        case "Noir":     return [Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.35, green: 0.35, blue: 0.40)]
        default:         return [Color(red: 0.36, green: 0.54, blue: 0.95), Color(red: 0.78, green: 0.89, blue: 1.00)]
        }
    }

    private static func customColors(for theme: String) -> [Color]? {
        if theme.hasPrefix("CustomGradient:") {
            guard let pair = theme.split(separator: ":").last?.split(separator: "-"),
                  pair.count == 2,
                  let first = UInt(pair[0], radix: 16),
                  let second = UInt(pair[1], radix: 16) else {
                return nil
            }

            return [Color(hex: first), Color(hex: second)]
        }

        if theme.hasPrefix("CustomSolid:") || theme.hasPrefix("Custom:") {
            guard let hex = theme.split(separator: ":").last,
                  let value = UInt(hex, radix: 16) else {
                return nil
            }

            let color = Color(hex: value)
            return [color, color]
        }

        return nil
    }
}

struct CourseTee: Identifiable, Equatable {
    let id = UUID()
    let databaseId: Int?
    let name: String    // e.g. "Championship", "Members", "Forward"
    let rating: Double  // course rating
    let slope: Int      // slope rating
}

struct CourseHole: Identifiable, Equatable {
    let id = UUID()
    let number: Int
    let par: Int
    let handicap: Int       // stroke index 1–18
    let yardages: [Int]     // [championship, members, forward]
}
