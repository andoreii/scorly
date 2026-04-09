//
// RoundDetailView.swift
// Full detail sheet for a completed round — summary-style stats, setup info, and scorecard.
//

import SwiftUI

struct RoundDetailView: View {
    let round: CompletedRound
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    private var displayedHoles: [CourseHole] {
        Array(round.holes.prefix(round.holesPlayed))
    }

    private var displayedHoleStats: [HoleStat] {
        Array(round.holeStats.prefix(round.holesPlayed))
    }

    private var hasStats: Bool { !round.holeStats.isEmpty }

    private var totalPar: Int {
        displayedHoles.reduce(0) { $0 + $1.par }
    }

    private var totalScore: Int {
        hasStats ? displayedHoleStats.reduce(0) { $0 + $1.strokes } : round.totalScore
    }

    private var scoreVsPar: Int {
        totalScore - totalPar
    }

    private var totalPutts: Int {
        displayedHoleStats.reduce(0) { $0 + $1.putts }
    }

    private var greensInReg: Int {
        zip(displayedHoleStats, displayedHoles).filter { $0.greenInReg(par: $1.par) }.count
    }

    private var fairwaysHit: Int {
        zip(displayedHoleStats, displayedHoles).filter { $0.fairwayInReg(par: $1.par) }.count
    }

    private var fairwaysApplicable: Int {
        displayedHoles.filter { $0.par > 3 }.count
    }

    private var totalPenaltyStrokes: Int {
        displayedHoleStats.reduce(0) { $0 + $1.penaltyStrokes }
    }

    private var totalHazards: Int {
        displayedHoleStats.reduce(0) { $0 + $1.hazardCount }
    }

    private var totalOOB: Int {
        displayedHoleStats.reduce(0) { $0 + $1.outOfBoundsCount }
    }

    private var upAndDowns: Int {
        displayedHoleStats.filter(\.upAndDownSuccess).count
    }

    private var sandSaves: Int {
        displayedHoleStats.filter(\.sandSaveSuccess).count
    }

    private var teeShotFairway: Int {
        displayedHoleStats.filter { $0.teeShot == "Fairway" || $0.teeShot == "Green" }.count
    }
    private var teeShotMissed: Int {
        displayedHoleStats.filter { s in
            guard let t = s.teeShot else { return false }
            return ["Left","Right","Short","Long"].contains(t)
        }.count
    }
    private var teeShotBunker: Int {
        displayedHoleStats.filter { $0.teeShot?.hasPrefix("Bunker") == true }.count
    }
    private var teeShotTrouble: Int {
        displayedHoleStats.filter { s in
            guard let t = s.teeShot else { return false }
            return t.contains("water") || t.contains("Water") || t.hasPrefix("Out ")
        }.count
    }

    private var girPercentage: Double {
        displayedHoles.isEmpty ? 0 : Double(greensInReg) / Double(displayedHoles.count)
    }

    private var fairwayPercentage: Double? {
        fairwaysApplicable > 0 ? Double(fairwaysHit) / Double(fairwaysApplicable) : nil
    }

    private var averagePuttsPerHole: Double {
        displayedHoles.isEmpty ? 0 : Double(totalPutts) / Double(displayedHoles.count)
    }

    private var threePuttCount: Int {
        displayedHoleStats.filter(\.threePutt).count
    }

    private var totalBunkers: Int {
        displayedHoleStats.filter {
            $0.teeShot == "Bunker" || $0.approach == "Bunker"
        }.count
    }

    private var scoreVsParText: String {
        if scoreVsPar == 0 { return "E" }
        return scoreVsPar > 0 ? "+\(scoreVsPar)" : "\(scoreVsPar)"
    }

    private var scoreColor: Color {
        if scoreVsPar < 0 { return Theme.Colors.success }
        if scoreVsPar > 8 { return Theme.Colors.error }
        return .white
    }

    private var conditionsDisplay: String {
        let conditionText = round.conditions.isEmpty ? nil : round.conditions
        let temperatureText = round.temperature.map { "\($0)°" }

        switch (conditionText, temperatureText) {
        case let (conditionText?, temperatureText?):
            return "\(conditionText) | \(temperatureText)"
        case let (conditionText?, nil):
            return conditionText
        case let (nil, temperatureText?):
            return temperatureText
        case (nil, nil):
            return ""
        }
    }

    private var frontNine: Range<Int> {
        0..<min(9, displayedHoles.count)
    }

    private var backNine: Range<Int> {
        displayedHoles.count > 9 ? 9..<displayedHoles.count : 0..<0
    }

    private var scoringDistribution: (under: Int, pars: Int, bogeys: Int, doubles: Int) {
        var under = 0
        var pars = 0
        var bogeys = 0
        var doubles = 0

        for (hole, stat) in zip(displayedHoles, displayedHoleStats) {
            switch stat.strokes - hole.par {
            case ..<0: under += 1
            case 0: pars += 1
            case 1: bogeys += 1
            default: doubles += 1
            }
        }

        return (under, pars, bogeys, doubles)
    }

    private var scoringDistributionTotal: Int {
        scoringDistribution.under + scoringDistribution.pars + scoringDistribution.bogeys + scoringDistribution.doubles
    }

    private struct MissData {
        let left: Int
        let right: Int
        let long: Int
        let short: Int

        var total: Int { left + right + long + short }
    }

    private struct DirFractions {
        let left: Double
        let right: Double
        let long: Double
        let short: Double
    }

    private func missData(from shots: [String?]) -> MissData {
        let values = shots.compactMap { $0 }
        return MissData(
            left: values.filter { $0.localizedCaseInsensitiveContains("left") }.count,
            right: values.filter { $0.localizedCaseInsensitiveContains("right") }.count,
            long: values.filter { $0.localizedCaseInsensitiveContains("long") }.count,
            short: values.filter { $0.localizedCaseInsensitiveContains("short") }.count
        )
    }

    private func dirFractions(from data: MissData) -> DirFractions {
        let total = max(data.total, 1)
        return DirFractions(
            left: Double(data.left) / Double(total),
            right: Double(data.right) / Double(total),
            long: Double(data.long) / Double(total),
            short: Double(data.short) / Double(total)
        )
    }

    private var teeMisses: MissData {
        missData(from: displayedHoleStats.map(\.teeShot))
    }

    private var approachMisses: MissData {
        missData(from: displayedHoleStats.map(\.approach))
    }

    private var teeDirections: DirFractions {
        dirFractions(from: teeMisses)
    }

    private var approachDirections: DirFractions {
        dirFractions(from: approachMisses)
    }

    var body: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    topBar
                    heroScore
                    if hasStats {
                        scorecardSection
                        statsSection
                    } else {
                        noStatsPlaceholder
                    }
                    notesSection
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.huge)
            }
            .scrollBounceBehavior(.basedOnSize)

            if showDeleteConfirm {
                DeleteRoundPopup(
                    onDelete: {
                        withAnimation(Theme.Animation.snappy) { showDeleteConfirm = false }
                        Task {
                            if let dbId = round.databaseId {
                                try? await DataService.shared.deleteRound(roundId: dbId)
                            }
                            onDelete?()
                            dismiss()
                        }
                    },
                    onCancel: {
                        withAnimation(Theme.Animation.snappy) { showDeleteConfirm = false }
                    }
                )
                .zIndex(99)
                .transition(.opacity)
                .animation(Theme.Animation.snappy, value: showDeleteConfirm)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if round.databaseId != nil {
                Button {
                    withAnimation(Theme.Animation.snappy) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "trash")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.error.opacity(0.60))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.Colors.textPrimary.opacity(0.07)))
                }
                .buttonStyle(ScorlyPressStyle())
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Theme.Colors.textPrimary.opacity(0.07)))
            }
            .buttonStyle(ScorlyPressStyle())
        }
        .padding(.top, Theme.Spacing.xxs)
    }

    private var heroScore: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: round.accentColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text(round.courseName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Text(Self.dateFmt.string(from: round.date))
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.top, Theme.Spacing.xxs)

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(scoreVsParText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                }

                HStack(spacing: Theme.Spacing.md) {
                    Text("Par \(totalPar)")
                    Text("\(displayedHoles.count) holes")
                    Text(round.tee + " tees")
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(.white.opacity(0.60))

                // Setup divider + items
                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)
                    .padding(.top, Theme.Spacing.sm)

                Text(([round.roundType, round.format, round.transport] + (conditionsDisplay.isEmpty ? [] : [conditionsDisplay])).joined(separator: "  ·  "))
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .themeShadow(Theme.Shadow.prominent)
    }

    // MARK: - No stats placeholder

    private var noStatsPlaceholder: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No detailed stats for this round")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("SCORING")
            distributionCard
                .padding(.top, Theme.Spacing.xs)

            sectionLabel("ACCURACY")
            accuracyCard
                .padding(.top, Theme.Spacing.xs)

            sectionLabel("PUTTING")
            puttingCard
                .padding(.top, Theme.Spacing.xs)

            sectionLabel("HAZARDS")
            hazardsCard
                .padding(.top, Theme.Spacing.xs)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.captionSmall)
            .foregroundStyle(Theme.Colors.textTertiary)
            .kerning(1.0)
            .padding(.top, Theme.Spacing.xl + 2)
    }

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geo in
                let width = geo.size.width
                let total = CGFloat(max(scoringDistributionTotal, 1))

                HStack(spacing: 2) {
                    if scoringDistribution.under > 0 {
                        Theme.Colors.success.frame(width: width * CGFloat(scoringDistribution.under) / total)
                    }
                    Theme.Colors.textSecondary.frame(width: width * CGFloat(scoringDistribution.pars) / total)
                    Theme.Colors.warning.frame(width: width * CGFloat(scoringDistribution.bogeys) / total)
                    if scoringDistribution.doubles > 0 {
                        Theme.Colors.error.frame(width: width * CGFloat(scoringDistribution.doubles) / total)
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(spacing: 9) {
                distributionRow(color: Theme.Colors.success, label: "Under Par", count: scoringDistribution.under)
                distributionRow(color: Theme.Colors.textSecondary, label: "Par", count: scoringDistribution.pars)
                distributionRow(color: Theme.Colors.warning, label: "Bogey", count: scoringDistribution.bogeys)
                distributionRow(color: Theme.Colors.error, label: "Double+", count: scoringDistribution.doubles)
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func distributionRow(color: Color, label: String, count: Int) -> some View {
        let percentage = scoringDistributionTotal > 0
            ? Int((Double(count) / Double(scoringDistributionTotal) * 100).rounded())
            : 0

        return HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text("\(count)")
                .font(Theme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
            Text("\(percentage)%")
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textTertiary)
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
    }

    private var accuracyCard: some View {
        HStack(alignment: .top, spacing: 0) {
            shotAccuracyPanel(
                title: "TEE SHOT",
                pctValue: fairwayPercentage.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                pctLabel: "Fairways Hit",
                detailText: fairwaysApplicable > 0 ? "\(fairwaysHit) of \(fairwaysApplicable)" : "No fairway holes",
                directions: teeDirections,
                missTotal: teeMisses.total
            )
            Rectangle()
                .fill(Theme.Colors.whisperBorder)
                .frame(width: 1)
            shotAccuracyPanel(
                title: "APPROACH",
                pctValue: "\(Int((girPercentage * 100).rounded()))%",
                pctLabel: "Greens in Reg",
                detailText: "\(greensInReg) of \(displayedHoles.count)",
                directions: approachDirections,
                missTotal: approachMisses.total
            )
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func shotAccuracyPanel(
        title: String,
        pctValue: String,
        pctLabel: String,
        detailText: String,
        directions: DirFractions,
        missTotal: Int
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textTertiary)
                .kerning(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, Theme.Spacing.sm)

            VStack(spacing: Theme.Spacing.xxxs) {
                Text(pctValue)
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(percentageColor(pctValue))
                    .monospacedDigit()
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: pctLabel == "Greens in Reg" ? "flag.fill" : "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(pctLabel)
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Text(detailText)
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, Theme.Spacing.md)

            if missTotal > 0 {
                Text("miss tendency")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .kerning(0.4)
                    .padding(.bottom, 10)

                missCompass(directions: directions)
            } else {
                Spacer(minLength: Theme.Spacing.lg)
                Text("No misses tracked")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer(minLength: Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentageColor(_ text: String) -> Color {
        let number = Int(text.replacingOccurrences(of: "%", with: "")) ?? 0
        if number >= 60 { return Theme.Colors.success }
        if number >= 40 { return Theme.Colors.textPrimary }
        return Theme.Colors.error
    }

    private func missCompass(directions: DirFractions) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            directionBubble(label: "Long", fraction: directions.long)
            HStack(spacing: Theme.Spacing.xxs + 2) {
                directionBubble(label: "Left", fraction: directions.left)
                compassRose
                directionBubble(label: "Right", fraction: directions.right)
            }
            directionBubble(label: "Short", fraction: directions.short)
        }
    }

    private var compassRose: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.textTertiary.opacity(0.5), lineWidth: 1.5)
                .frame(width: 30, height: 30)
            Circle()
                .fill(Theme.Colors.whisperBorder)
                .frame(width: 10, height: 10)
        }
    }

    private func directionBubble(label: String, fraction: Double) -> some View {
        let percentage = Int((fraction * 100).rounded())
        let alpha = 0.18 + min(fraction, 1.0) * 0.82
        let icon: String = switch label {
        case "Left": "arrow.left"
        case "Right": "arrow.right"
        case "Long": "arrow.up"
        case "Short": "arrow.down"
        default: "circle"
        }

        return VStack(spacing: 1) {
            Text("\(percentage)%")
                .font(Theme.Typography.caption)
                .fontWeight(.bold)
                .foregroundStyle(Theme.Colors.textPrimary.opacity(alpha))
                .monospacedDigit()
            HStack(spacing: Theme.Spacing.xxxs) {
                Image(systemName: icon)
                    .font(.system(size: 7, weight: .bold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Theme.Colors.textPrimary.opacity(alpha * 0.6))
        }
        .frame(width: 46)
    }

    private var puttingCard: some View {
        HStack(spacing: 0) {
            puttingCell(value: "\(totalPutts)", label: "Total Putts")
            Divider().frame(height: 32)
            puttingCell(
                value: String(format: "%.2f", averagePuttsPerHole),
                label: "Per Hole",
                color: averagePuttsPerHole <= 1.8 ? Theme.Colors.success : Theme.Colors.textPrimary
            )
            Divider().frame(height: 32)
            puttingCell(
                value: "\(threePuttCount)",
                label: "3-Putts",
                color: threePuttCount > 0 ? Theme.Colors.error : Theme.Colors.textPrimary
            )
        }
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func puttingCell(value: String, label: String, color: Color = Theme.Colors.textPrimary) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.title)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var hazardsCard: some View {
        HStack(spacing: 0) {
            hazardCell(icon: "figure.golf", label: "Bunker", value: totalBunkers, color: Theme.Colors.bunker)
            Divider().frame(height: 44)
            hazardCell(icon: "drop.fill", label: "Water", value: totalHazards, color: Theme.Colors.water)
            Divider().frame(height: 44)
            hazardCell(icon: "xmark", label: "OOB", value: totalOOB, color: Theme.Colors.error)
        }
        .padding(.vertical, Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func hazardCell(icon: String, label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(color.opacity(0.65))
            Text("\(value)")
                .font(Theme.Typography.title)
                .foregroundStyle(value > 0 ? color : Theme.Colors.textPrimary)
                .monospacedDigit()
            VStack(spacing: 1) {
                Text(label)
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text("this round")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if let notes = round.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Notes")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: "note.text")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.top, Theme.Spacing.xxxs)
                    Text(notes)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
                .themeShadow(Theme.Shadow.subtle)
            }
        }
    }

    // MARK: - Scorecard

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("SCORECARD")

            VStack(spacing: Theme.Spacing.md) {
                scorecardNineBlock(title: "Front 9", range: frontNine)

                if !backNine.isEmpty {
                    scorecardNineBlock(title: "Back 9", range: backNine)
                }

                totalScoreSummary
            }
            .padding(Theme.Spacing.cardPadding)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
            .themeShadow(Theme.Shadow.subtle)
            .padding(.top, Theme.Spacing.xs)
        }
    }

    private func scorecardNineBlock(title: String, range: Range<Int>) -> some View {
        let holes = Array(displayedHoles[range])
        let stats = Array(displayedHoleStats[range])
        let parSum = holes.reduce(0) { $0 + $1.par }
        let scoreSum = stats.reduce(0) { $0 + $1.strokes }
        let delta = scoreSum - parSum

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                summaryPill(text: "Par \(parSum)")
                summaryPill(text: "Score \(scoreSum)")
                summaryPill(
                    text: vsParText(delta),
                    foreground: vsParColor(delta),
                    background: vsParColor(delta).opacity(0.12)
                )
            }

            VStack(spacing: 8) {
                scorecardGridRow(
                    label: "Hole",
                    values: holes.map { "\($0.number)" },
                    style: .plain
                )
                scorecardGridRow(
                    label: "Par",
                    values: holes.map { "\($0.par)" },
                    style: .muted
                )
                scorecardGridRow(
                    label: "Score",
                    values: zip(holes, stats).map { scoreGridValue(strokes: $1.strokes, delta: $1.strokes - $0.par) },
                    style: .scoreBadge
                )
                scorecardGridRow(
                    label: "+/-",
                    values: zip(holes, stats).map { scoreGridValue(text: vsParText($1.strokes - $0.par), tint: vsParColor($1.strokes - $0.par)) },
                    style: .delta
                )
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.canvas)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }

    private var totalScoreSummary: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                Text("Round Total")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text("\(totalScore)")
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: Theme.Spacing.xs) {
                totalMetric(text: "Par \(totalPar)")
                totalMetric(
                    text: scoreVsParText,
                    foreground: scoreVsPar <= 0 ? vsParColor(scoreVsPar) : Theme.Colors.error,
                    background: (scoreVsPar <= 0 ? vsParColor(scoreVsPar) : Theme.Colors.error).opacity(0.12)
                )
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
    }

    private func summaryPill(
        text: String,
        foreground: Color = Theme.Colors.textPrimary,
        background: Color = Theme.Colors.surface
    ) -> some View {
        Text(text)
            .font(Theme.Typography.captionSmall)
            .foregroundStyle(foreground)
            .monospacedDigit()
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs + 1)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }

    private func totalMetric(
        text: String,
        foreground: Color = Theme.Colors.textPrimary,
        background: Color = Theme.Colors.surface
    ) -> some View {
        Text(text)
            .font(Theme.Typography.bodySemibold)
            .foregroundStyle(foreground)
            .monospacedDigit()
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm + 4, style: .continuous)
                    .fill(background)
            )
    }

    private enum ScorecardGridStyle {
        case plain
        case muted
        case scoreBadge
        case delta
    }

    private struct ScoreGridValue: Identifiable {
        let id = UUID()
        let text: String
        let tint: Color
        let fill: Color?
    }

    private func scoreGridValue(text: String, tint: Color, fill: Color? = nil) -> ScoreGridValue {
        ScoreGridValue(text: text, tint: tint, fill: fill)
    }

    private func scoreGridValue(strokes: Int, delta: Int) -> ScoreGridValue {
        let colors = scoreBadgeColors(delta: delta)
        return ScoreGridValue(text: "\(strokes)", tint: colors.1, fill: colors.0)
    }

    private func scorecardGridRow(label: String, values: [String], style: ScorecardGridStyle) -> some View {
        scorecardGridRow(
            label: label,
            values: values.map { ScoreGridValue(text: $0, tint: style == .muted ? Theme.Colors.textTertiary : Theme.Colors.textPrimary, fill: nil) },
            style: style
        )
    }

    private func scorecardGridRow(label: String, values: [ScoreGridValue], style: ScorecardGridStyle) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(style == .plain ? Theme.Colors.textSecondary : Theme.Colors.textTertiary)
                .frame(width: 34, alignment: .leading)

            ForEach(values) { value in
                scorecardGridCell(value: value, style: style)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func scorecardGridCell(value: ScoreGridValue, style: ScorecardGridStyle) -> some View {
        Group {
            switch style {
            case .scoreBadge:
                Text(value.text)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(value.tint)
                    .monospacedDigit()
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(value.fill ?? Theme.Colors.surface)
                    )
            case .delta:
                Text(value.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(value.tint)
                    .monospacedDigit()
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
            case .plain, .muted:
                Text(value.text)
                    .font(.system(size: 12, weight: style == .plain ? .semibold : .medium))
                    .foregroundStyle(value.tint)
                    .monospacedDigit()
                    .frame(height: 22)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(Theme.Colors.surface.opacity(style == .muted ? 0.75 : 1))
                    )
            }
        }
    }

    private func vsParText(_ diff: Int) -> String {
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func vsParColor(_ diff: Int) -> Color {
        switch diff {
        case ...(-2): return Theme.Colors.success
        case -1: return Theme.Colors.success
        case 0: return Theme.Colors.textPrimary
        case 1: return Theme.Colors.textPrimary
        default: return Theme.Colors.error
        }
    }

    private func scoreBadge(strokes: Int, delta: Int) -> some View {
        let (bg, fg) = scoreBadgeColors(delta: delta)
        return Text("\(strokes)")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(bg))
            .monospacedDigit()
    }

    private func scoreBadgeColors(delta: Int) -> (Color, Color) {
        switch delta {
        case ..<(-1): return (Theme.Colors.success, .white)
        case -1: return (Theme.Colors.success.opacity(0.15), Theme.Colors.success)
        case 0: return (Theme.Colors.textPrimary.opacity(0.06), Theme.Colors.textPrimary)
        case 1: return (Theme.Colors.warning.opacity(0.18), Theme.Colors.warning)
        default: return (Theme.Colors.error.opacity(0.14), Theme.Colors.error)
        }
    }
}
