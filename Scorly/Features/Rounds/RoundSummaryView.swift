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
    @State private var appeared = false
    @State private var scoreAnimated = false
    // confirmPulse removed — button is static

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
        if scoreVsPar < 0  { return Theme.Colors.success }
        if scoreVsPar > 8  { return Theme.Colors.error }
        return Theme.Colors.textPrimary
    }

    private var frontNine: Range<Int> { 0..<min(9, holes.count) }
    private var backNine: Range<Int>  { holes.count > 9 ? 9..<holes.count : 0..<0 }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    topBar
                    heroScore
                        .scaleEffect(scoreAnimated ? 1 : 0.5)
                        .opacity(scoreAnimated ? 1 : 0)
                        .animation(Theme.Animation.bouncy.delay(0.15), value: scoreAnimated)
                    statsSection
                        .staggeredAppear(index: 2, isVisible: appeared)
                    notesSection
                        .staggeredAppear(index: 4, isVisible: appeared)
                    scorecardSection
                        .staggeredAppear(index: 6, isVisible: appeared)
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, 120)
            }
            .scrollBounceBehavior(.basedOnSize)

            confirmButton
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    Theme.Colors.canvas
                        .shadow(color: Theme.Colors.textPrimary.opacity(0.07), radius: 16, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .onAppear {
            notesText = roundStore.activeRound?.notes ?? notesText
            withAnimation(Theme.Animation.bouncy) {
                scoreAnimated = true
            }
            withAnimation(Theme.Animation.smooth.delay(0.2)) {
                appeared = true
            }
            // pulse animation removed — confirm button is static
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Theme.Colors.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
            }
            .buttonStyle(ScorlyPressStyle())

            Spacer()

            Text("Round Summary")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Color.clear.frame(width: 42, height: 42)
        }
        .frame(height: 44)
    }

    // MARK: - Hero score

    private var heroScore: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: course.accentColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.13), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                Text(course.name)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("\(totalScore)")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(scoreVsParText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                HStack(spacing: Theme.Spacing.md) {
                    Text("Par \(totalPar)")
                    Text("\(holes.count) holes")
                    if teeIndex < course.tees.count {
                        Text(course.tees[teeIndex].name + " tees")
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(.white.opacity(0.60))

                if let active = roundStore.activeRound {
                    let setupParts: [String] = ([active.roundType, active.roundFormat, active.transport]
                        + (active.conditions.isEmpty ? [] : [active.conditions.joined(separator: ", ")]))
                        .filter { !$0.isEmpty }
                    if !setupParts.isEmpty {
                        Text(setupParts.joined(separator: "  ·  "))
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .themeShadow(Theme.Shadow.prominent)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xxs + 2) {
                Image(systemName: "chart.bar.fill")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text("Round Stats")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            VStack(spacing: 0) {
                // GIR + Fairways
                HStack(spacing: 0) {
                    percentageContent(
                        title: "GIR",
                        madeCount: greensInReg,
                        totalCount: holes.count,
                        progress: girPercentage,
                        tint: Theme.Colors.success
                    )
                    Divider()
                    percentageContent(
                        title: "Fairways",
                        madeCount: fairwaysHit,
                        totalCount: fairwaysApplicable,
                        progress: fairwayPercentage,
                        tint: Theme.Colors.water,
                        emptyState: "N/A"
                    )
                }

                Divider()

                // Tee shots
                HStack(spacing: 0) {
                    teeShotItem(icon: "checkmark.circle.fill", label: "Fairway", count: teeShotFairway,
                                color: Theme.Colors.success)
                    Divider().frame(height: 30)
                    teeShotItem(icon: "arrow.left.and.right", label: "Missed", count: teeShotMissed,
                                color: Theme.Colors.warning)
                    Divider().frame(height: 30)
                    teeShotItem(icon: "oval.fill", label: "Bunker", count: teeShotBunker,
                                color: Theme.Colors.bunker)
                    Divider().frame(height: 30)
                    teeShotItem(icon: "exclamationmark.triangle.fill", label: "Trouble", count: teeShotTrouble,
                                color: Theme.Colors.error)
                }
                .padding(.vertical, Theme.Spacing.sm + 2)

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
                .padding(.vertical, Theme.Spacing.xs)

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
                .padding(.horizontal, Theme.Spacing.sm + 2)
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
            .themeShadow(Theme.Shadow.subtle)
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
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer(minLength: Theme.Spacing.sm)

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

            Spacer(minLength: Theme.Spacing.sm)

            HStack {
                Text(totalCount > 0 ? "\(madeCount)/\(totalCount)" : "No attempts")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm + 2)
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
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer(minLength: Theme.Spacing.sm)

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

            Spacer(minLength: Theme.Spacing.sm)

            HStack {
                Text(totalCount > 0 ? "\(madeCount)/\(totalCount)" : "No attempts")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 148)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private var teeShotCard: some View {
        HStack(spacing: 0) {
            teeShotItem(icon: "checkmark.circle.fill", label: "Fairway", count: teeShotFairway,
                        color: Theme.Colors.success)
            Divider().frame(height: 30)
            teeShotItem(icon: "arrow.left.and.right", label: "Missed", count: teeShotMissed,
                        color: Theme.Colors.warning)
            Divider().frame(height: 30)
            teeShotItem(icon: "oval.fill", label: "Bunker", count: teeShotBunker,
                        color: Theme.Colors.bunker)
            Divider().frame(height: 30)
            teeShotItem(icon: "exclamationmark.triangle.fill", label: "Trouble", count: teeShotTrouble,
                        color: Theme.Colors.error)
        }
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func teeShotItem(icon: String, label: String, count: Int, color: Color) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(count > 0 ? color : Theme.Colors.textTertiary.opacity(0.5))
            Text("\(count)")
                .font(Theme.Typography.title)
                .foregroundStyle(count > 0 ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)
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
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func puttingMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text(label)
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text(value)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var compactStatsCard: some View {
        VStack(spacing: 0) {
            compactStatRow(
                leftIcon: "exclamationmark.circle", leftLabel: "Penalties", leftValue: "\(totalPenaltyStrokes)",
                rightIcon: "drop.fill", rightLabel: "Hazards", rightValue: "\(totalHazards)"
            )
            Divider()
                .padding(.horizontal, Theme.Spacing.sm + 2)
            compactStatRow(
                leftIcon: "arrow.up.right.and.arrow.down.left", leftLabel: "OOB", leftValue: "\(totalOOB)",
                rightIcon: "arrow.up.arrow.down", rightLabel: "Up & Down", rightValue: "\(upAndDowns)"
            )
            Divider()
                .padding(.horizontal, Theme.Spacing.sm + 2)
            singleCompactStatRow(icon: "oval.fill", label: "Sand Saves", value: "\(sandSaves)")
        }
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func compactStatRow(
        leftIcon: String, leftLabel: String, leftValue: String,
        rightIcon: String?, rightLabel: String?, rightValue: String?
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            compactStatItem(icon: leftIcon, label: leftLabel, value: leftValue)

            if let rightLabel, let rightValue, let rightIcon {
                Divider()
                    .frame(height: 30)
                compactStatItem(icon: rightIcon, label: rightLabel, value: rightValue)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func singleCompactStatRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs + 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer(minLength: Theme.Spacing.xs)

            Text(value)
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func compactStatItem(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xxs + 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer(minLength: Theme.Spacing.xs)

            Text(value)
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Notes")
                .font(Theme.Typography.bodySemibold)
                .foregroundStyle(Theme.Colors.textPrimary)

            TextField("Add notes about this round", text: $notesText, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(4...8)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
                )
                .themeShadow(Theme.Shadow.subtle)
                .onChange(of: notesText) { _, value in
                    roundStore.updateNotes(value)
                }
        }
    }

    // MARK: - Scorecard

    private var scorecardSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xxs + 2) {
                Image(systemName: "tablecells")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text("Scorecard")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            VStack(spacing: 0) {
                headerRow
                Divider().padding(.horizontal, Theme.Spacing.sm + 2)

                ForEach(0..<holes.count, id: \.self) { idx in
                    holeRow(idx: idx)
                    if idx == 8 && holes.count == 18 {
                        Divider().padding(.horizontal, Theme.Spacing.sm + 2)
                        subtotalRow(label: "Out", range: frontNine)
                        Divider().padding(.horizontal, Theme.Spacing.sm + 2)
                    } else if idx < holes.count - 1 {
                        Divider().padding(.horizontal, Theme.Spacing.sm + 2).opacity(0.45)
                    }
                }

                if holes.count == 18 {
                    Divider().padding(.horizontal, Theme.Spacing.sm + 2)
                    subtotalRow(label: "In", range: backNine)
                }

                Divider().padding(.horizontal, Theme.Spacing.sm + 2)
                totalRow
            }
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
            .themeShadow(Theme.Shadow.subtle)
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
        .font(Theme.Typography.captionSmall)
        .foregroundStyle(Theme.Colors.textTertiary)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func holeRow(idx: Int) -> some View {
        let hole = holes[idx]
        let stat = holeStats[idx]
        let diff = stat.strokes - hole.par

        return HStack(spacing: 0) {
            Text("\(hole.number)")
                .frame(width: 44, alignment: .leading)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("\(hole.par)")
                .frame(width: 36, alignment: .center)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
            scoreBadge(strokes: stat.strokes, delta: diff)
                .frame(width: 52, alignment: .center)
            Text(vsParText(diff))
                .frame(width: 38, alignment: .trailing)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(vsParColor(diff))
                .monospacedDigit()
        }
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.xs)
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
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.canvas)
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
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.sm)
        .monospacedDigit()
    }

    // MARK: - Confirm button

    private var confirmButton: some View {
        Button(action: {
            roundStore.finishRoundToRounds()
        }) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(Theme.Typography.title2)
                Text("Confirm & Finish")
                    .font(Theme.Typography.title2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .themeShadow(Theme.Shadow.glow)
        }
        .buttonStyle(ScorlyPressStyle())
        // pulse removed — static button
    }

    // MARK: - Helpers

    private func vsParText(_ diff: Int) -> String {
        if diff == 0 { return "E" }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func vsParColor(_ diff: Int) -> Color {
        switch diff {
        case ...(-2): return Theme.Colors.success
        case -1:      return Theme.Colors.success
        case 0:       return Theme.Colors.textPrimary
        case 1:       return Theme.Colors.textPrimary
        default:      return Theme.Colors.error
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
        case -1:      return (Theme.Colors.success.opacity(0.15), Theme.Colors.success)
        case 0:       return (Theme.Colors.textPrimary.opacity(0.06), Theme.Colors.textPrimary)
        case 1:       return (Theme.Colors.warning.opacity(0.18), Theme.Colors.warning)
        default:      return (Theme.Colors.error.opacity(0.14), Theme.Colors.error)
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
                .stroke(Theme.Colors.whisperBorder, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(centerLabel)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
        }
    }
}
