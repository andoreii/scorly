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

    private let cr: CGFloat = 13

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

    private var scoreVsParText: String {
        if scoreVsPar == 0 { return "E" }
        return scoreVsPar > 0 ? "+\(scoreVsPar)" : "\(scoreVsPar)"
    }

    private var scoreColor: Color {
        if scoreVsPar < 0 { return Color(red: 0.353, green: 0.620, blue: 0.365) }
        if scoreVsPar > 8 { return Color(red: 0.70, green: 0.15, blue: 0.15) }
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

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    heroScore
                    if hasStats {
                        statsSection
                        scorecardSection
                    } else {
                        noStatsPlaceholder
                    }
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .scrollBounceBehavior(.basedOnSize)

            if showDeleteConfirm {
                DeleteRoundPopup(
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.18)) { showDeleteConfirm = false }
                        Task {
                            if let dbId = round.databaseId {
                                try? await DataService.shared.deleteRound(roundId: dbId)
                            }
                            onDelete?()
                            dismiss()
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.18)) { showDeleteConfirm = false }
                    }
                )
                .zIndex(99)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: showDeleteConfirm)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if round.databaseId != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.24).opacity(0.60))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.black.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.50))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.black.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var heroScore: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(red: 0.16, green: 0.16, blue: 0.19)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text(round.courseName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Text(Self.dateFmt.string(from: round.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.top, 4)

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(scoreVsParText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    Text("Par \(totalPar)")
                    Text("\(displayedHoles.count) holes")
                    Text(round.tee + " tees")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.60))

                // Setup divider + items
                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)
                    .padding(.top, 12)

                Text(([round.roundType, round.format, round.transport] + (conditionsDisplay.isEmpty ? [] : [conditionsDisplay])).joined(separator: "  ·  "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 8)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }

    // MARK: - No stats placeholder

    private var noStatsPlaceholder: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black.opacity(0.25))
            Text("No detailed stats for this round")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    // MARK: - Stats (single card)

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
                Text("Round Stats")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
            }

            VStack(spacing: 0) {

                // GIR + Fairways
                HStack(spacing: 0) {
                    percentageContent(
                        title: "GIR",
                        madeCount: greensInReg,
                        totalCount: displayedHoles.count,
                        progress: girPercentage,
                        tint: Color(red: 0.486, green: 0.718, blue: 0.498)
                    )
                    Divider()
                    percentageContent(
                        title: "Fairways",
                        madeCount: fairwaysHit,
                        totalCount: fairwaysApplicable,
                        progress: fairwayPercentage,
                        tint: Color(red: 0.14, green: 0.35, blue: 0.72),
                        emptyState: "N/A"
                    )
                }

                Divider()

                // Tee shots
                HStack(spacing: 0) {
                    teeShotItem(icon: "checkmark.circle.fill", label: "Fairway", count: teeShotFairway,
                                color: Color(red: 0.486, green: 0.718, blue: 0.498))
                    Divider().frame(height: 30)
                    teeShotItem(icon: "arrow.left.and.right", label: "Missed", count: teeShotMissed,
                                color: Color(red: 0.94, green: 0.67, blue: 0.16))
                    Divider().frame(height: 30)
                    teeShotItem(icon: "oval.fill", label: "Bunker", count: teeShotBunker,
                                color: Color(red: 0.82, green: 0.65, blue: 0.38))
                    Divider().frame(height: 30)
                    teeShotItem(icon: "exclamationmark.triangle.fill", label: "Trouble", count: teeShotTrouble,
                                color: Color(red: 0.88, green: 0.28, blue: 0.24))
                }
                .padding(.vertical, 14)

                Divider()

                // Putting
                HStack(spacing: 0) {
                    puttingMetric(value: "\(totalPutts)", label: "Total Putts")
                    Divider().frame(height: 44)
                    puttingMetric(
                        value: String(format: "%.1f", averagePuttsPerHole),
                        label: "Avg Putts / Hole"
                    )
                }
                .padding(.vertical, 8)

                Divider()

                // Compact stats
                VStack(spacing: 0) {
                    compactStatRow(
                        leftIcon: "exclamationmark.circle", leftLabel: "Penalties", leftValue: "\(totalPenaltyStrokes)",
                        rightIcon: "drop.fill", rightLabel: "Hazards", rightValue: "\(totalHazards)"
                    )
                    Divider()
                    compactStatRow(
                        leftIcon: "arrow.up.right.and.arrow.down.left", leftLabel: "OOB", leftValue: "\(totalOOB)",
                        rightIcon: "arrow.up.arrow.down", rightLabel: "Up & Down", rightValue: "\(upAndDowns)"
                    )
                    Divider()
                    singleCompactStatRow(icon: "oval.fill", label: "Sand Saves", value: "\(sandSaves)")
                }
                .padding(.horizontal, 14)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
    }

    private func percentageContent(
        title: String,
        madeCount: Int,
        totalCount: Int,
        progress: Double?,
        tint: Color,
        emptyState: String = "0%"
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black.opacity(0.52))

            Spacer(minLength: 12)

            HStack {
                Spacer(minLength: 0)
                RoundDetailDonutChart(
                    progress: progress,
                    tint: tint,
                    lineWidth: 10,
                    centerLabel: progress.map { "\(Int(($0 * 100).rounded()))%" } ?? emptyState
                )
                .frame(width: 62, height: 62)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 12)

            HStack {
                Text(totalCount > 0 ? "\(madeCount)/\(totalCount)" : "No attempts")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func teeShotItem(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(count > 0 ? color : .black.opacity(0.18))
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(count > 0 ? .black : .black.opacity(0.25))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private func puttingMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.38))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.52))
            }

            Text(value)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.black)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactStatRow(
        leftIcon: String, leftLabel: String, leftValue: String,
        rightIcon: String?, rightLabel: String?, rightValue: String?
    ) -> some View {
        HStack(spacing: 16) {
            compactStatItem(icon: leftIcon, label: leftLabel, value: leftValue)

            if let rightLabel, let rightValue, let rightIcon {
                Divider()
                    .frame(height: 30)
                compactStatItem(icon: rightIcon, label: rightLabel, value: rightValue)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 12)
    }

    private func singleCompactStatRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.black.opacity(0.38))
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black.opacity(0.58))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }

    private func compactStatItem(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.black.opacity(0.38))
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black.opacity(0.58))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if let notes = round.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.35))
                        .padding(.top, 2)
                    Text(notes)
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
            }
        }
    }

    // MARK: - Scorecard

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tablecells")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
                Text("Scorecard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
            }

            VStack(spacing: 0) {
                headerRow
                Divider().padding(.horizontal, 14)

                ForEach(displayedHoles.indices, id: \.self) { idx in
                    holeRow(idx: idx)
                    if idx == 8 && displayedHoles.count == 18 {
                        Divider().padding(.horizontal, 14)
                        subtotalRow(label: "Out", range: frontNine)
                        Divider().padding(.horizontal, 14)
                    } else if idx < displayedHoles.count - 1 {
                        Divider().padding(.horizontal, 14).opacity(0.45)
                    }
                }

                if displayedHoles.count == 18 {
                    Divider().padding(.horizontal, 14)
                    subtotalRow(label: "In", range: backNine)
                }

                Divider().padding(.horizontal, 14)
                totalRow
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Hole").frame(width: 44, alignment: .leading)
            Text("Par").frame(width: 36, alignment: .center)
            Spacer()
            Text("Score").frame(width: 52, alignment: .center)
            Text("+/-").frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.black.opacity(0.40))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func holeRow(idx: Int) -> some View {
        let hole = displayedHoles[idx]
        let stat = displayedHoleStats[idx]
        let diff = stat.strokes - hole.par

        return HStack(spacing: 0) {
            Text("\(hole.number)")
                .frame(width: 44, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black)
            Text("\(hole.par)")
                .frame(width: 36, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))
            Spacer()
            scoreBadge(strokes: stat.strokes, delta: diff)
                .frame(width: 52, alignment: .center)
            Text(vsParText(diff))
                .frame(width: 38, alignment: .trailing)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(vsParColor(diff))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func subtotalRow(label: String, range: Range<Int>) -> some View {
        let parSum = displayedHoles[range].reduce(0) { $0 + $1.par }
        let scoreSum = displayedHoleStats[range].reduce(0) { $0 + $1.strokes }
        let diff = scoreSum - parSum

        return HStack(spacing: 0) {
            Text(label).frame(width: 44, alignment: .leading)
            Text("\(parSum)").frame(width: 36, alignment: .center)
            Spacer()
            Text("\(scoreSum)").frame(width: 52, alignment: .center)
            Text(vsParText(diff))
                .foregroundStyle(vsParColor(diff))
                .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
    }

    private var totalRow: some View {
        HStack(spacing: 0) {
            Text("Total").frame(width: 44, alignment: .leading)
            Text("\(totalPar)").frame(width: 36, alignment: .center)
            Spacer()
            Text("\(totalScore)").frame(width: 52, alignment: .center)
            Text(scoreVsParText)
                .foregroundStyle(scoreVsPar <= 0 ? vsParColor(scoreVsPar) : Color(red: 0.70, green: 0.15, blue: 0.15))
                .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .monospacedDigit()
    }

    private func vsParText(_ diff: Int) -> String {
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func vsParColor(_ diff: Int) -> Color {
        switch diff {
        case ...(-2): return Color(red: 0.08, green: 0.50, blue: 0.26)
        case -1: return Color(red: 0.13, green: 0.60, blue: 0.32)
        case 0: return .black
        case 1: return .black
        default: return Color(red: 0.70, green: 0.15, blue: 0.15)
        }
    }

    private func scoreBadge(strokes: Int, delta: Int) -> some View {
        let (bg, fg) = scoreBadgeColors(delta: delta)
        return Text("\(strokes)")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(bg))
            .monospacedDigit()
    }

    private func scoreBadgeColors(delta: Int) -> (Color, Color) {
        switch delta {
        case ..<(-1): return (Color(red: 0.10, green: 0.60, blue: 0.30), .white)
        case -1: return (Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.15), Color(red: 0.416, green: 0.682, blue: 0.427))
        case 0: return (Color.black.opacity(0.06), .black)
        case 1: return (Color(red: 0.94, green: 0.67, blue: 0.16).opacity(0.18), Color(red: 0.72, green: 0.48, blue: 0.05))
        default: return (Color(red: 0.88, green: 0.28, blue: 0.24).opacity(0.14), Color(red: 0.75, green: 0.18, blue: 0.15))
        }
    }
}

private struct RoundDetailDonutChart: View {
    let progress: Double?
    let tint: Color
    let lineWidth: CGFloat
    let centerLabel: String

    private var clampedProgress: Double {
        min(max(progress ?? 0, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(centerLabel)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .monospacedDigit()
        }
    }
}
