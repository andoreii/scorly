//
// LocalModels.swift
// SwiftData models used for local caching — mirrors the Supabase schema.
//

import SwiftData
import Foundation

@Model
final class LocalCourse {
    @Attribute(.unique) var courseId: Int
    var userId: String
    var courseName: String
    var location: String?
    var notes: String?
    var colorTheme: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var tees: [LocalTee] = []
    @Relationship(deleteRule: .cascade) var holes: [LocalHole] = []

    init(from row: CourseRow) {
        self.courseId  = row.courseId
        self.userId    = row.userId.uuidString
        self.courseName = row.courseName
        self.location  = row.location
        self.notes     = row.notes
        self.colorTheme = row.colorTheme
        self.createdAt = row.createdAt
    }

    func update(from row: CourseRow) {
        courseName  = row.courseName
        location    = row.location
        notes       = row.notes
        colorTheme  = row.colorTheme
    }
}

@Model
final class LocalTee {
    @Attribute(.unique) var teeId: Int
    var courseId: Int
    var teeName: String
    var courseRating: Double?
    var slopeRating: Double?
    var yardage: Int?

    @Relationship(deleteRule: .cascade) var teeHoles: [LocalTeeHole] = []

    init(from row: TeeRow) {
        self.teeId        = row.teeId
        self.courseId     = row.courseId
        self.teeName      = row.teeName
        self.courseRating = row.courseRating
        self.slopeRating  = row.slopeRating
        self.yardage      = row.yardage
    }
}

@Model
final class LocalHole {
    @Attribute(.unique) var holeId: Int
    var courseId: Int
    var holeNumber: Int
    var par: Int
    var holeHandicapIndex: Int?

    init(from row: HoleRow) {
        self.holeId             = row.holeId
        self.courseId           = row.courseId
        self.holeNumber         = row.holeNumber
        self.par                = row.par
        self.holeHandicapIndex  = row.holeHandicapIndex
    }
}

@Model
final class LocalTeeHole {
    @Attribute(.unique) var teeHoleId: Int
    var teeId: Int
    var holeNumber: Int
    var yardage: Int

    init(from row: TeeHoleRow) {
        self.teeHoleId  = row.teeHoleId
        self.teeId      = row.teeId
        self.holeNumber = row.holeNumber
        self.yardage    = row.yardage
    }
}

@Model
final class LocalRound {
    @Attribute(.unique) var roundId: Int
    var userId: String
    var courseId: Int
    var teeId: Int?
    var datePlayed: String
    var holesPlayed: String
    var roundType: String?
    var roundFormat: String?
    var conditions: String?
    var temperature: Int?
    var walkingVsRiding: String?
    var timeOfDay: String?
    var mentalState: Int?
    var notes: String?
    var whsDifferential: Double?
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var holeStats: [LocalHoleStat] = []

    init(from row: RoundRow) {
        self.roundId          = row.roundId
        self.userId           = row.userId.uuidString
        self.courseId         = row.courseId
        self.teeId            = row.teeId
        self.datePlayed       = row.datePlayed
        self.holesPlayed      = row.holesPlayed
        self.roundType        = row.roundType
        self.roundFormat      = row.roundFormat
        self.conditions       = row.conditions
        self.temperature      = row.temperature
        self.walkingVsRiding  = row.walkingVsRiding
        self.timeOfDay        = row.timeOfDay
        self.mentalState      = row.mentalState
        self.notes            = row.notes
        self.whsDifferential  = row.whsDifferential
        self.createdAt        = row.createdAt
    }
}

@Model
final class LocalHoleStat {
    @Attribute(.unique) var holeStatId: Int
    var roundId: Int
    var holeNumber: Int
    var strokes: Int
    var putts: Int
    var teeShot: String?
    var approach: String?
    var teeClub: String?
    var approachClub: String?
    var outOfBoundsCount: Int
    var penaltyStrokes: Int
    var hazardCount: Int
    var greenInReg: Bool?
    var threePutt: Bool?
    var girOpportunity: Bool?
    var fairwayOpportunity: Bool?
    var upAndDownSuccess: Bool?
    var sandSaveSuccess: Bool?

    init(from row: HoleStatRow) {
        self.holeStatId         = row.holeStatId
        self.roundId            = row.roundId
        self.holeNumber         = row.holeNumber
        self.strokes            = row.strokes
        self.putts              = row.putts
        self.teeShot            = row.teeShot
        self.approach           = row.approach
        self.teeClub            = row.teeClub
        self.approachClub       = row.approachClub
        self.outOfBoundsCount   = row.outOfBoundsCount
        self.penaltyStrokes     = row.penaltyStrokes
        self.hazardCount        = row.hazardCount
        self.greenInReg         = row.greenInReg
        self.threePutt          = row.threePutt
        self.girOpportunity     = row.girOpportunity
        self.fairwayOpportunity = row.fairwayOpportunity
        self.upAndDownSuccess   = row.upAndDownSuccess
        self.sandSaveSuccess    = row.sandSaveSuccess
    }
}

@Model
final class LocalUser {
    @Attribute(.unique) var id: String
    var handicapIndex: Double?
    var createdAt: Date

    init(from row: UserRow) {
        self.id            = row.id.uuidString
        self.handicapIndex = row.handicapIndex
        self.createdAt     = row.createdAt
    }
}
