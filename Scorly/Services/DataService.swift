//
// DataService.swift
// Supabase data layer — CRUD operations for courses, rounds, and hole stats.
//

import Supabase
import Foundation

// MARK: - Database row types (Codable ↔ Supabase tables)

private enum SupabaseTimestamp {
    static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func decode(_ value: String) throws -> Date {
        if let date = fractionalFormatter.date(from: value) ?? formatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Invalid Supabase timestamp: \(value)")
        )
    }
}

struct CourseRow: Decodable, Identifiable {
    let courseId: Int
    let userId: UUID
    let courseName: String
    let location: String?
    let notes: String?
    let colorTheme: String?
    let createdAt: Date

    var id: Int { courseId }

    // Nested — populated when using select("*, tees(...), holes(...)")
    var tees: [TeeRow]?
    var holes: [HoleRow]?

    private enum CodingKeys: String, CodingKey {
        case courseId
        case userId
        case courseName
        case location
        case notes
        case colorTheme
        case createdAt
        case tees
        case holes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.courseId = try container.decode(Int.self, forKey: .courseId)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.courseName = try container.decode(String.self, forKey: .courseName)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.colorTheme = try container.decodeIfPresent(String.self, forKey: .colorTheme)
        let createdAtValue = try container.decode(String.self, forKey: .createdAt)
        self.createdAt = try SupabaseTimestamp.decode(createdAtValue)
        self.tees = try container.decodeIfPresent([TeeRow].self, forKey: .tees)
        self.holes = try container.decodeIfPresent([HoleRow].self, forKey: .holes)
    }
}

struct TeeRow: Codable, Identifiable {
    let teeId: Int
    let courseId: Int
    let teeName: String
    let courseRating: Double?
    let slopeRating: Double?
    let yardage: Int?
    var teeHoles: [TeeHoleRow]?

    var id: Int { teeId }
}

struct HoleRow: Codable, Identifiable {
    let holeId: Int
    let courseId: Int
    let holeNumber: Int
    let par: Int
    let holeHandicapIndex: Int?

    var id: Int { holeId }
}

struct TeeHoleRow: Codable, Identifiable {
    let teeHoleId: Int
    let teeId: Int
    let holeNumber: Int
    let yardage: Int

    var id: Int { teeHoleId }
}

struct RoundRow: Decodable, Identifiable {
    let roundId: Int
    let userId: UUID
    let courseId: Int
    let teeId: Int?
    let datePlayed: String   // "YYYY-MM-DD" — PostgreSQL DATE
    let holesPlayed: String
    let roundType: String?
    let roundFormat: String?
    let conditions: String?
    let temperature: Int?
    let walkingVsRiding: String?
    let timeOfDay: String?
    let mentalState: Int?
    let roundExternalId: String?
    let notes: String?
    let whsDifferential: Double?
    let totalScore: Int?
    let createdAt: Date

    var id: Int { roundId }

    var holeStats: [HoleStatRow]?

    private enum CodingKeys: String, CodingKey {
        case roundId
        case userId
        case courseId
        case teeId
        case datePlayed
        case holesPlayed
        case roundType
        case roundFormat
        case conditions
        case temperature
        case walkingVsRiding
        case timeOfDay
        case mentalState
        case roundExternalId
        case notes
        case whsDifferential
        case totalScore
        case createdAt
        case holeStats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.roundId = try container.decode(Int.self, forKey: .roundId)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.courseId = try container.decode(Int.self, forKey: .courseId)
        self.teeId = try container.decodeIfPresent(Int.self, forKey: .teeId)
        self.datePlayed = try container.decode(String.self, forKey: .datePlayed)
        self.holesPlayed = try container.decode(String.self, forKey: .holesPlayed)
        self.roundType = try container.decodeIfPresent(String.self, forKey: .roundType)
        self.roundFormat = try container.decodeIfPresent(String.self, forKey: .roundFormat)
        self.conditions = try container.decodeIfPresent(String.self, forKey: .conditions)
        self.temperature = try container.decodeIfPresent(Int.self, forKey: .temperature)
        self.walkingVsRiding = try container.decodeIfPresent(String.self, forKey: .walkingVsRiding)
        self.timeOfDay = try container.decodeIfPresent(String.self, forKey: .timeOfDay)
        self.mentalState = try container.decodeIfPresent(Int.self, forKey: .mentalState)
        self.roundExternalId = try container.decodeIfPresent(String.self, forKey: .roundExternalId)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.whsDifferential = try container.decodeIfPresent(Double.self, forKey: .whsDifferential)
        self.totalScore = try container.decodeIfPresent(Int.self, forKey: .totalScore)
        let createdAtValue = try container.decode(String.self, forKey: .createdAt)
        self.createdAt = try SupabaseTimestamp.decode(createdAtValue)
        self.holeStats = try container.decodeIfPresent([HoleStatRow].self, forKey: .holeStats)
    }
}

struct HoleStatRow: Codable, Identifiable {
    let holeStatId: Int
    let roundId: Int
    let holeNumber: Int
    let strokes: Int
    let putts: Int
    let teeShot: String?
    let approach: String?
    let teeClub: String?
    let approachClub: String?
    let outOfBoundsCount: Int
    let penaltyStrokes: Int
    let hazardCount: Int
    let greenInReg: Bool?
    let threePutt: Bool?
    let girOpportunity: Bool?
    let fairwayOpportunity: Bool?
    let upAndDownSuccess: Bool?
    let sandSaveSuccess: Bool?

    var id: Int { holeStatId }
}

struct UserRow: Decodable {
    let id: UUID
    let handicapIndex: Double?
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case handicapIndex
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.handicapIndex = try container.decodeIfPresent(Double.self, forKey: .handicapIndex)
        let createdAtValue = try container.decode(String.self, forKey: .createdAt)
        self.createdAt = try SupabaseTimestamp.decode(createdAtValue)
    }
}

// MARK: - Insert payloads (no generated fields)

struct CourseInsert: Encodable {
    let userId: UUID
    let courseName: String
    let location: String?
    let notes: String?
    let colorTheme: String?
}

struct CourseUpdate: Encodable {
    let courseName: String
    let location: String?
    let notes: String?
    let colorTheme: String?
}

struct TeeInsert: Encodable {
    let courseId: Int
    let teeName: String
    let courseRating: Double?
    let slopeRating: Double?
    let yardage: Int?
}

struct TeeUpdate: Encodable {
    let teeName: String
    let courseRating: Double?
    let slopeRating: Double?
    let yardage: Int?
}

struct HoleInsert: Encodable {
    let courseId: Int
    let holeNumber: Int
    let par: Int
    let holeHandicapIndex: Int?
}

struct HoleUpdate: Encodable {
    let par: Int
    let holeHandicapIndex: Int?
}

struct TeeHoleInsert: Encodable {
    let teeId: Int
    let holeNumber: Int
    let yardage: Int
}

struct RoundInsert: Encodable {
    let userId: UUID
    let courseId: Int
    let teeId: Int?
    let datePlayed: String
    let holesPlayed: String
    let roundType: String?
    let roundFormat: String?
    let conditions: String?
    let temperature: Int?
    let walkingVsRiding: String?
    let timeOfDay: String?
    let mentalState: Int?
    let roundExternalId: String?
    let notes: String?
    let whsDifferential: Double?
}

struct HoleStatInsert: Encodable {
    let roundId: Int
    let holeNumber: Int
    let strokes: Int
    let putts: Int
    let teeShot: String?
    let approach: String?
    let teeClub: String?
    let approachClub: String?
    let outOfBoundsCount: Int
    let penaltyStrokes: Int
    let hazardCount: Int
    let greenInReg: Bool?
    let threePutt: Bool?
    let girOpportunity: Bool?
    let fairwayOpportunity: Bool?
    let upAndDownSuccess: Bool?
    let sandSaveSuccess: Bool?
}

// MARK: - DataService

@MainActor
class DataService {

    static let shared = DataService()
    private init() {}
    private let courseSelect = "*, tees(*, tee_holes(*)), holes(*)"

    // MARK: User profile

    func fetchUserProfile() async throws -> UserRow? {
        try await supabase
            .from("users")
            .select()
            .single()
            .execute()
            .value
    }

    func updateHandicapIndex(_ value: Double) async throws {
        guard let uid = try? await supabase.auth.session.user.id else { return }
        try await supabase
            .from("users")
            .update(["handicap_index": value])
            .eq("id", value: uid.uuidString)
            .execute()
    }

    // MARK: Courses

    func fetchCourses() async throws -> [CourseRow] {
        try await supabase
            .from("courses")
            .select(courseSelect)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchCourse(courseId: Int) async throws -> CourseRow {
        try await supabase
            .from("courses")
            .select(courseSelect)
            .eq("course_id", value: courseId)
            .single()
            .execute()
            .value
    }

    /// Inserts a full course (course + tees + holes + tee_holes) in one transaction.
    func saveCourse(
        name: String,
        location: String?,
        notes: String?,
        colorTheme: String?,
        tees: [(name: String, rating: Double?, slope: Double?, yardage: Int?)],
        holes: [(number: Int, par: Int, handicap: Int?)],
        teeHoleYardages: [[Int]]   // [teeIndex][holeIndex] = yardage
    ) async throws -> CourseRow {
        guard let uid = try? await supabase.auth.session.user.id else {
            throw URLError(.userAuthenticationRequired)
        }

        // 1. Insert course
        let courseRow: CourseRow = try await supabase
            .from("courses")
            .insert(CourseInsert(
                userId: uid,
                courseName: name,
                location: location,
                notes: notes,
                colorTheme: colorTheme
            ))
            .select()
            .single()
            .execute()
            .value

        let courseId = courseRow.courseId

        // 2. Insert tees
        let teeInserts = tees.map {
            TeeInsert(courseId: courseId, teeName: $0.name, courseRating: $0.rating, slopeRating: $0.slope, yardage: $0.yardage)
        }
        let insertedTees: [TeeRow] = try await supabase
            .from("tees")
            .insert(teeInserts)
            .select()
            .execute()
            .value

        // 3. Insert holes
        let holeInserts = holes.map {
            HoleInsert(courseId: courseId, holeNumber: $0.number, par: $0.par, holeHandicapIndex: $0.handicap)
        }
        try await supabase
            .from("holes")
            .insert(holeInserts)
            .execute()

        // 4. Insert tee_holes
        var teeHoleInserts: [TeeHoleInsert] = []
        for (teeIdx, tee) in insertedTees.enumerated() {
            guard teeIdx < teeHoleYardages.count else { continue }
            let yardages = teeHoleYardages[teeIdx]
            for (holeIdx, hole) in holes.enumerated() {
                guard holeIdx < yardages.count else { continue }
                teeHoleInserts.append(TeeHoleInsert(
                    teeId: tee.teeId,
                    holeNumber: hole.number,
                    yardage: yardages[holeIdx]
                ))
            }
        }
        if !teeHoleInserts.isEmpty {
            try await supabase
                .from("tee_holes")
                .insert(teeHoleInserts)
                .execute()
        }

        return try await fetchCourse(courseId: courseId)
    }

    func updateCourse(
        courseId: Int,
        name: String,
        location: String?,
        notes: String?,
        colorTheme: String?,
        tees: [(databaseId: Int?, name: String, rating: Double?, slope: Double?, yardage: Int?)],
        holes: [(number: Int, par: Int, handicap: Int?)],
        teeHoleYardages: [[Int]]
    ) async throws -> CourseRow {
        try await supabase
            .from("courses")
            .update(CourseUpdate(
                courseName: name,
                location: location,
                notes: notes,
                colorTheme: colorTheme
            ))
            .eq("course_id", value: courseId)
            .execute()

        let existingCourse = try await fetchCourse(courseId: courseId)
        let existingTees = (existingCourse.tees ?? []).sorted { $0.teeId < $1.teeId }
        let incomingTeeIds = Set(tees.compactMap(\.databaseId))

        for hole in holes {
            try await supabase
                .from("holes")
                .update(HoleUpdate(par: hole.par, holeHandicapIndex: hole.handicap))
                .eq("course_id", value: courseId)
                .eq("hole_number", value: hole.number)
                .execute()
        }

        for obsoleteTeeId in existingTees.map(\.teeId).filter({ !incomingTeeIds.contains($0) }) {
            try await supabase
                .from("tees")
                .delete()
                .eq("tee_id", value: obsoleteTeeId)
                .execute()
        }

        for (teeIndex, tee) in tees.enumerated() {
            guard teeIndex < teeHoleYardages.count else { continue }

            let yardages = teeHoleYardages[teeIndex]
            let totalYardage = yardages.reduce(0, +)
            let yardageValue = totalYardage > 0 ? totalYardage : tee.yardage

            let teeId: Int
            if let existingTeeId = tee.databaseId {
                teeId = existingTeeId
                try await supabase
                    .from("tees")
                    .update(TeeUpdate(
                        teeName: tee.name,
                        courseRating: tee.rating,
                        slopeRating: tee.slope,
                        yardage: yardageValue
                    ))
                    .eq("tee_id", value: existingTeeId)
                    .execute()
            } else {
                let insertedTee: TeeRow = try await supabase
                    .from("tees")
                    .insert(TeeInsert(
                        courseId: courseId,
                        teeName: tee.name,
                        courseRating: tee.rating,
                        slopeRating: tee.slope,
                        yardage: yardageValue
                    ))
                    .select()
                    .single()
                    .execute()
                    .value
                teeId = insertedTee.teeId
            }

            try await supabase
                .from("tee_holes")
                .delete()
                .eq("tee_id", value: teeId)
                .execute()

            let teeHoleInserts: [TeeHoleInsert] = holes.enumerated().compactMap { holeIndex, hole in
                guard holeIndex < yardages.count else { return nil }
                return TeeHoleInsert(
                    teeId: teeId,
                    holeNumber: hole.number,
                    yardage: yardages[holeIndex]
                )
            }

            if !teeHoleInserts.isEmpty {
                try await supabase
                    .from("tee_holes")
                    .insert(teeHoleInserts)
                    .execute()
            }
        }

        return try await fetchCourse(courseId: courseId)
    }

    func deleteCourse(courseId: Int) async throws {
        try await supabase
            .from("courses")
            .delete()
            .eq("course_id", value: courseId)
            .execute()
    }

    // MARK: Rounds

    func fetchRounds() async throws -> [RoundRow] {
        try await supabase
            .from("rounds")
            .select("*, hole_stats(*)")
            .order("date_played", ascending: false)
            .execute()
            .value
    }

    func saveRound(
        courseId: Int,
        teeId: Int?,
        datePlayed: Date,
        holesPlayed: String,
        roundType: String?,
        roundFormat: String?,
        conditions: String?,
        temperature: Int?,
        walkingVsRiding: String?,
        timeOfDay: String?,
        mentalState: Int?,
        roundExternalId: String?,
        notes: String?,
        whsDifferential: Double?,
        holeStats: [(
            holeNumber: Int,
            strokes: Int,
            putts: Int,
            teeShot: String?,
            approach: String?,
            teeClub: String?,
            approachClub: String?,
            outOfBoundsCount: Int,
            penaltyStrokes: Int,
            hazardCount: Int,
            greenInReg: Bool?,
            threePutt: Bool?,
            girOpportunity: Bool?,
            fairwayOpportunity: Bool?,
            upAndDownSuccess: Bool?,
            sandSaveSuccess: Bool?
        )]
    ) async throws -> RoundRow {
        guard let uid = try? await supabase.auth.session.user.id else {
            throw URLError(.userAuthenticationRequired)
        }

        let dateStr = ISO8601DateFormatter.yyyyMMdd.string(from: datePlayed)

        // 1. Insert round
        let round: RoundRow = try await supabase
            .from("rounds")
            .insert(RoundInsert(
                userId: uid,
                courseId: courseId,
                teeId: teeId,
                datePlayed: dateStr,
                holesPlayed: holesPlayed,
                roundType: roundType,
                roundFormat: roundFormat,
                conditions: conditions,
                temperature: temperature,
                walkingVsRiding: walkingVsRiding,
                timeOfDay: timeOfDay,
                mentalState: mentalState,
                roundExternalId: roundExternalId,
                notes: notes,
                whsDifferential: whsDifferential
            ))
            .select()
            .single()
            .execute()
            .value

        // 2. Insert hole stats
        let statInserts = holeStats.map {
            HoleStatInsert(
                roundId: round.roundId,
                holeNumber: $0.holeNumber,
                strokes: $0.strokes,
                putts: $0.putts,
                teeShot: $0.teeShot,
                approach: $0.approach,
                teeClub: $0.teeClub,
                approachClub: $0.approachClub,
                outOfBoundsCount: $0.outOfBoundsCount,
                penaltyStrokes: $0.penaltyStrokes,
                hazardCount: $0.hazardCount,
                greenInReg: $0.greenInReg,
                threePutt: $0.threePutt,
                girOpportunity: $0.girOpportunity,
                fairwayOpportunity: $0.fairwayOpportunity,
                upAndDownSuccess: $0.upAndDownSuccess,
                sandSaveSuccess: $0.sandSaveSuccess
            )
        }
        if !statInserts.isEmpty {
            try await supabase
                .from("hole_stats")
                .insert(statInserts)
                .execute()
        }

        return round
    }

    func deleteRound(roundId: Int) async throws {
        try await supabase
            .from("rounds")
            .delete()
            .eq("round_id", value: roundId)
            .execute()
    }
}

// MARK: - Helpers

private extension ISO8601DateFormatter {
    static let yyyyMMdd: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}
