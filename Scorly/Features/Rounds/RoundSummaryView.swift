//
// RoundSummaryView.swift
// Post-round summary — scorecard, stats, and confirm finish.
//

import SwiftUI

struct RoundSummaryView: View {
    let course: Course
    let holes: [CourseHole]
    let holeStats: [HoleStat]
    let teeIndex: Int

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore
    @State private var notesText = ""

    private let cr: CGFloat = 13

    // MARK: - Computed

    private var totalPar: Int   { holes.reduce(0) { $0 + $1.par } }
    private var totalScore: Int { holeStats.reduce(0) { $0 + $1.strokes } }
    private var scoreVsPar: Int { totalScore - totalPar }
    private var totalPutts: Int { holeStats.reduce(0) { $0 + $1.putts } }

    private var greensInReg: Int {
        zip(holeStats, holes).filter { $0.greenInReg(par: $1.par) }.count
    }
    private var fairwaysHit: Int {
        zip(holeStats, holes).filter { $0.fairwayInReg(par: $1.par) }.count
    }
    private var fairwaysApplicable: Int {
        holes.filter { $0.par > 3 }.count
    }
    private var totalPenaltyStrokes: Int {
        holeStats.reduce(0) { $0 + $1.penaltyStrokes }
    }
    private var totalHazards: Int {
        holeStats.reduce(0) { $0 + $1.hazardCount }
    }
    private var totalOOB: Int {
        holeStats.reduce(0) { $0 + $1.outOfBoundsCount }
    }
    private var upAndDowns: Int {
        holeStats.filter(\.upAndDownSuccess).count
    }
    private var sandSaves: Int {
        holeStats.filter(\.sandSaveSuccess).count
    }
    private var girPercentage: Double { holes.isEmpty ? 0 : Double(greensInReg) / Double(holes.count) }
    private var fairwayPercentage: Double? {
        fairwaysApplicable > 0 ? Double(fairwaysHit) / Double(fairwaysApplicable) : nil
    }
    private var averagePuttsPerHole: Double {
        holes.isEmpty ? 0 : Double(totalPutts) / Double(holes.count)
    }

    private var teeShotFairway: Int {
        holeStats.filter { $0.teeShot == "Fairway" || $0.teeShot == "Green" }.count
    }
    private var teeShotMissed: Int {
        holeStats.filter { s in
            guard let t = s.teeShot else { return false }
            return ["Left","Right","Short","Long"].contains(t)
        }.count
    }
    private var teeShotBunker: Int {
        holeStats.filter { $0.teeShot?.hasPrefix("Bunker") == true }.count
    }
    private var teeShotTrouble: Int {
        holeStats.filter { s in
            guard let t = s.teeShot else { return false }
            return t.contains("water") || t.contains("Water") || t.hasPrefix("Out ")
        }.count
    }

    private var scoreVsParText: String {
        if scoreVsPar == 0 { return "E" }
        return scoreVsPar > 0 ? "+\(scoreVsPar)" : "\(scoreVsPar)"
    }

    private var scoreColor: Color {
        if scoreVsPar < 0  { return Color(red: 0.353, green: 0.620, blue: 0.365) }
        if scoreVsPar > 8  { return Color(red: 0.70, green: 0.15, blue: 0.15) }
        return .black
    }

    private var frontNine: Range<Int> { 0..<min(9, holes.count) }
    private var backNine: Range<Int>  { holes.count > 9 ? 9..<holes.count : 0..<0 }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    heroScore
                    statsSection
                    notesSection
                    scorecardSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollBounceBehavior(.basedOnSize)

            confirmButton
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Color(red: 0.97, green: 0.97, blue: 0.98)
                        .shadow(color: .black.opacity(0.07), radius: 16, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .onAppear {
            notesText = roundStore.activeRound?.notes ?? notesText
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
                    .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Round Summary")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)

            Spacer()

            Color.clear.frame(width: 42, height: 42)
        }
        .frame(height: 44)
    }

    // MARK: - Hero score

    private var heroScore: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: course.accentColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.13), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text(course.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(scoreVsParText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    Text("Par \(totalPar)")
                    Text("\(holes.count) holes")
                    if teeIndex < course.tees.count {
                        Text(course.tees[teeIndex].name + " tees")
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.60))

                if let active = roundStore.activeRound {
                    let setupParts: [String] = ([active.roundType, active.roundFormat, active.transport]
                        + (active.conditions.isEmpty ? [] : [active.conditions.joined(separator: ", ")]))
                        .filter { !$0.isEmpty }
                    if !setupParts.isEmpty {
                        Text(setupParts.joined(separator: "  ·  "))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }

    // MARK: - Stats

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
                        totalCount: holes.count,
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
                DonutChart(
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

    private func percentageCard(
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
                DonutChart(
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
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private var teeShotCard: some View {
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
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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

    private var puttingCard: some View {
        HStack(spacing: 0) {
            puttingMetric(
                value: "\(totalPutts)",
                label: "Total Putts"
            )

            Divider()
                .frame(height: 44)

            puttingMetric(
                value: String(format: "%.1f", averagePuttsPerHole),
                label: "Avg Putts / Hole"
            )
        }
        .padding(.vertical, 8)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var compactStatsCard: some View {
        VStack(spacing: 0) {
            compactStatRow(
                leftIcon: "exclamationmark.circle", leftLabel: "Penalties", leftValue: "\(totalPenaltyStrokes)",
                rightIcon: "drop.fill", rightLabel: "Hazards", rightValue: "\(totalHazards)"
            )
            Divider()
                .padding(.horizontal, 14)
            compactStatRow(
                leftIcon: "arrow.up.right.and.arrow.down.left", leftLabel: "OOB", leftValue: "\(totalOOB)",
                rightIcon: "arrow.up.arrow.down", rightLabel: "Up & Down", rightValue: "\(upAndDowns)"
            )
            Divider()
                .padding(.horizontal, 14)
            singleCompactStatRow(icon: "oval.fill", label: "Sand Saves", value: "\(sandSaves)")
        }
        .padding(.horizontal, 14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)

            TextField("Add notes about this round", text: $notesText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(.black)
                .lineLimit(4...8)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .strokeBorder(.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                .onChange(of: notesText) { _, value in
                    roundStore.updateNotes(value)
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

                ForEach(0..<holes.count, id: \.self) { idx in
                    holeRow(idx: idx)
                    if idx == 8 && holes.count == 18 {
                        Divider().padding(.horizontal, 14)
                        subtotalRow(label: "Out", range: frontNine)
                        Divider().padding(.horizontal, 14)
                    } else if idx < holes.count - 1 {
                        Divider().padding(.horizontal, 14).opacity(0.45)
                    }
                }

                if holes.count == 18 {
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
            Text("Par") .frame(width: 36, alignment: .center)
            Spacer()
            Text("Score").frame(width: 52, alignment: .center)
            Text("+/-")  .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.black.opacity(0.40))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func holeRow(idx: Int) -> some View {
        let hole = holes[idx]
        let stat = holeStats[idx]
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
        let parSum   = holes[range].reduce(0)     { $0 + $1.par }
        let scoreSum = holeStats[range].reduce(0) { $0 + $1.strokes }
        let diff     = scoreSum - parSum

        return HStack(spacing: 0) {
            Text(label)             .frame(width: 44, alignment: .leading)
            Text("\(parSum)")       .frame(width: 36, alignment: .center)
            Spacer()
            Text("\(scoreSum)")     .frame(width: 52, alignment: .center)
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
            Text("Total")              .frame(width: 44, alignment: .leading)
            Text("\(totalPar)")        .frame(width: 36, alignment: .center)
            Spacer()
            Text("\(totalScore)")      .frame(width: 52, alignment: .center)
            Text(scoreVsParText)
                .foregroundStyle(scoreColor)
                .frame(width: 38, alignment: .trailing)
        }
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .monospacedDigit()
    }

    // MARK: - Confirm button

    private var confirmButton: some View {
        Button(action: {
            roundStore.finishRoundToRounds()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Confirm & Finish")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.22, green: 0.22, blue: 0.24), Color.black],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func vsParText(_ diff: Int) -> String {
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func vsParColor(_ diff: Int) -> Color {
        switch diff {
        case ...(-2): return Color(red: 0.08, green: 0.50, blue: 0.26)
        case -1:      return Color(red: 0.13, green: 0.60, blue: 0.32)
        case 0:       return .black
        case 1:       return .black
        default:      return Color(red: 0.70, green: 0.15, blue: 0.15)
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
        case -1:      return (Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.15), Color(red: 0.416, green: 0.682, blue: 0.427))
        case 0:       return (Color.black.opacity(0.06), .black)
        case 1:       return (Color(red: 0.94, green: 0.67, blue: 0.16).opacity(0.18), Color(red: 0.72, green: 0.48, blue: 0.05))
        default:      return (Color(red: 0.88, green: 0.28, blue: 0.24).opacity(0.14), Color(red: 0.75, green: 0.18, blue: 0.15))
        }
    }
}

private struct DonutChart: View {
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
