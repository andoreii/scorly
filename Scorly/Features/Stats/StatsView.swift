//
// StatsView.swift
// Career statistics — handicap, scoring, accuracy, performance, hazards and putting.
//

import SwiftUI

fileprivate struct RadarMetric: Identifiable {
    let id = UUID()
    let label: String
    let score: Double
    let detail: String
    let color: Color
}

struct StatsView: View {
    @Environment(TabMotionCoordinator.self) private var tabMotion
    @State private var allRounds: [CompletedRound] = []
    @State private var radarAnimated = false
    @State private var radarAnimationToken = 0

    private var rounds: [CompletedRound] {
        Array(allRounds.sorted { $0.date > $1.date }.prefix(20))
    }

    private var isActiveTab: Bool {
        tabMotion.activeTab == 3
    }

    // MARK: – Overview

    private var roundCount: Int { rounds.count }
    private var avgScore: Int {
        guard !rounds.isEmpty else { return 0 }
        return rounds.map(\.totalScore).reduce(0, +) / rounds.count
    }
    private var bestScore: Int { rounds.map(\.totalScore).min() ?? 0 }
    private var handicap: Double? { CompletedRound.handicapIndex(from: Array(rounds.sorted { $0.date < $1.date }.suffix(20))) }
    private var isImproving: Bool {
        let s = rounds.sorted { $0.date < $1.date }
        guard s.count >= 4 else { return false }
        return s.suffix(2).map(\.totalScore).reduce(0,+)/2 < s.prefix(2).map(\.totalScore).reduce(0,+)/2
    }

    // MARK: – GIR / FIR

    private var totalHoles: Int  { rounds.reduce(0) { $0 + $1.holesPlayed } }
    private var totalGIR: Int    { rounds.reduce(0) { $0 + $1.greensInReg } }
    private var girFraction: Double { totalHoles > 0 ? Double(totalGIR) / Double(totalHoles) : 0 }
    private var girText: String  { totalHoles > 0 ? "\(Int((girFraction*100).rounded()))%" : "—" }

    private var totalFIRApp: Int { rounds.reduce(0) { $0 + $1.fairwaysApplicable } }
    private var totalFIRHit: Int { rounds.reduce(0) { $0 + $1.fairwaysHit } }
    private var firFraction: Double { totalFIRApp > 0 ? Double(totalFIRHit) / Double(totalFIRApp) : 0 }
    private var firText: String  { totalFIRApp > 0 ? "\(Int((firFraction*100).rounded()))%" : "—" }

    // MARK: – Putting

    private var totalPutts: Int { rounds.reduce(0) { $0 + $1.totalPutts } }
    private var avgPuttsPerRound: Double { rounds.isEmpty ? 0 : Double(totalPutts) / Double(rounds.count) }
    private var avgPuttsPerHole: Double  { totalHoles > 0 ? Double(totalPutts) / Double(totalHoles) : 0 }
    private var threePuttCount: Int { rounds.reduce(0) { $0 + $1.holeStats.filter(\.threePutt).count } }
    private var threePuttRate: Double { totalHoles > 0 ? Double(threePuttCount) / Double(totalHoles) : 0 }

    // MARK: – Complete game

    private var totalScoreVsPar: Int {
        rounds.reduce(0) { $0 + ($1.totalScore - $1.par) }
    }
    private var avgScoreVsParPerHole: Double {
        totalHoles > 0 ? Double(totalScoreVsPar) / Double(totalHoles) : 0
    }
    private var upAndDownSuccessCount: Int {
        rounds.reduce(0) { $0 + $1.holeStats.filter(\.upAndDownSuccess).count }
    }
    private var missedGIRCount: Int { max(totalHoles - totalGIR, 0) }
    private var upAndDownRate: Double {
        missedGIRCount > 0 ? Double(upAndDownSuccessCount) / Double(missedGIRCount) : 0
    }
    private var bunkerOpportunityCount: Int {
        rounds.flatMap(\.holeStats).filter {
            $0.teeShot == "Bunker" || $0.approach == "Bunker"
        }.count
    }
    private var sandSaveCount: Int {
        rounds.reduce(0) { $0 + $1.holeStats.filter(\.sandSaveSuccess).count }
    }
    private var sandSaveRate: Double {
        bunkerOpportunityCount > 0 ? Double(sandSaveCount) / Double(bunkerOpportunityCount) : 0
    }
    private var troubleEvents: Int {
        rounds.flatMap(\.holeStats).reduce(0) {
            $0 + $1.penaltyStrokes + $1.outOfBoundsCount + $1.hazardCount
        }
    }
    private var troubleRatePerHole: Double {
        totalHoles > 0 ? Double(troubleEvents) / Double(totalHoles) : 0
    }
    private var shortGameScore: Double {
        bunkerOpportunityCount > 0
            ? (upAndDownRate + sandSaveRate) / 2
            : upAndDownRate
    }
    private var puttingScore: Double {
        let pace = normalizedInverse(avgPuttsPerHole, best: 1.5, worst: 2.3)
        let avoidance = normalizedInverse(threePuttRate, best: 0.0, worst: 0.18)
        return (pace + avoidance) / 2
    }
    private var scoringScore: Double {
        normalizedInverse(max(avgScoreVsParPerHole, 0), best: 0, worst: 0.8)
    }
    private var troubleAvoidanceScore: Double {
        normalizedInverse(troubleRatePerHole, best: 0, worst: 0.35)
    }
    private var completeGameMetrics: [RadarMetric] {
        [
            RadarMetric(
                label: "Scoring",
                score: scoringScore,
                detail: rounds.isEmpty ? "No rounds" : "Avg \(avgScore)",
                color: Theme.Colors.scoring
            ),
            RadarMetric(
                label: "Driving",
                score: firFraction,
                detail: totalFIRApp > 0 ? "\(Int((firFraction * 100).rounded()))% FIR" : "No FIR data",
                color: Theme.Colors.driving
            ),
            RadarMetric(
                label: "Approach",
                score: girFraction,
                detail: totalHoles > 0 ? "\(Int((girFraction * 100).rounded()))% GIR" : "No GIR data",
                color: Theme.Colors.approach
            ),
            RadarMetric(
                label: "Short Game",
                score: shortGameScore,
                detail: bunkerOpportunityCount > 0
                    ? "\(Int((shortGameScore * 100).rounded()))% combined"
                    : (missedGIRCount > 0 ? "\(Int((upAndDownRate * 100).rounded()))% up-and-down" : "No short game data"),
                color: Theme.Colors.shortGame
            ),
            RadarMetric(
                label: "Putting",
                score: puttingScore,
                detail: totalHoles > 0 ? String(format: "%.2f putts/hole", avgPuttsPerHole) : "No putting data",
                color: Theme.Colors.putting
            ),
            RadarMetric(
                label: "Trouble",
                score: troubleAvoidanceScore,
                detail: totalHoles > 0 ? String(format: "%.2f trouble/hole", troubleRatePerHole) : "No trouble data",
                color: Theme.Colors.trouble
            )
        ]
    }

    // MARK: – Scoring distribution

    private var dist: (under: Int, pars: Int, bogeys: Int, doubles: Int) {
        var u = 0, p = 0, b = 0, d = 0
        for round in rounds {
            for (hole, stat) in zip(round.holes, round.holeStats) {
                switch stat.strokes - hole.par {
                case ..<0: u += 1
                case 0:    p += 1
                case 1:    b += 1
                default:   d += 1
                }
            }
        }
        return (u, p, b, d)
    }
    private var distTotal: Int { dist.under + dist.pars + dist.bogeys + dist.doubles }

    // MARK: – Par-type performance

    private func avgVsPar(_ par: Int) -> Double {
        var total = 0, count = 0
        for round in rounds {
            for (hole, stat) in zip(round.holes, round.holeStats) where hole.par == par {
                total += stat.strokes - hole.par; count += 1
            }
        }
        return count > 0 ? Double(total) / Double(count) : 0
    }

    // MARK: – Miss direction data

    private struct MissData {
        let left: Int; let right: Int; let long: Int; let short: Int
        var total: Int { left + right + long + short }
    }

    private struct DirFractions {
        let left: Double; let right: Double; let long: Double; let short: Double
    }

    private func missData(from shots: [String?]) -> MissData {
        let vals = shots.compactMap { $0 }
        return MissData(
            left:  vals.filter { $0.contains("Left")  || $0.contains("left")  }.count,
            right: vals.filter { $0.contains("Right") || $0.contains("right") }.count,
            long:  vals.filter { $0.contains("Long")  || $0.contains("long")  }.count,
            short: vals.filter { $0.contains("Short") || $0.contains("short") }.count
        )
    }

    private func dirFractions(from data: MissData) -> DirFractions {
        let t = max(data.total, 1)
        return DirFractions(
            left:  Double(data.left)  / Double(t),
            right: Double(data.right) / Double(t),
            long:  Double(data.long)  / Double(t),
            short: Double(data.short) / Double(t)
        )
    }

    private var teeMisses:  MissData { missData(from: rounds.flatMap { $0.holeStats.map(\.teeShot) }) }
    private var appMisses:  MissData { missData(from: rounds.flatMap { $0.holeStats.map(\.approach) }) }
    private var appDirs:    DirFractions { dirFractions(from: appMisses) }
    private var teeDirs:    DirFractions { dirFractions(from: teeMisses) }

    // MARK: – Hazards

    private var totalOOB:    Int { rounds.flatMap(\.holeStats).reduce(0) { $0 + $1.outOfBoundsCount } }
    private var totalWater:  Int { rounds.flatMap(\.holeStats).reduce(0) { $0 + $1.hazardCount } }
    private var totalBunker: Int {
        rounds.flatMap(\.holeStats).filter {
            $0.teeShot == "Bunker" || $0.approach == "Bunker"
        }.count
    }
    private var avgBunkerPerRound: Double { rounds.isEmpty ? 0 : Double(totalBunker) / Double(rounds.count) }
    private var avgWaterPerRound:  Double { rounds.isEmpty ? 0 : Double(totalWater)  / Double(rounds.count) }
    private var avgOOBPerRound:    Double { rounds.isEmpty ? 0 : Double(totalOOB)    / Double(rounds.count) }

    // MARK: – Body

    var body: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    Text("Stats")
                        .font(Theme.Typography.monoDisplay)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .tabReveal(tab: 3, order: 0)
                        .padding(.bottom, Theme.Spacing.lg)

                    heroCard
                        .tabReveal(tab: 3, order: 1)

                    sectionLabel("COMPLETE GAME")
                        .tabReveal(tab: 3, order: 2)
                    radarCard.padding(.top, Theme.Spacing.xs)
                        .tabReveal(tab: 3, order: 3)

                    sectionLabel("SCORING")
                        .tabReveal(tab: 3, order: 4)
                    distributionCard.padding(.top, Theme.Spacing.xs)
                        .tabReveal(tab: 3, order: 5)

                    sectionLabel("ACCURACY")
                        .tabReveal(tab: 3, order: 6)
                    accuracyCard.padding(.top, Theme.Spacing.xs)
                        .tabReveal(tab: 3, order: 7)

                    sectionLabel("PERFORMANCE")
                        .tabReveal(tab: 3, order: 8)
                    parTypeCard.padding(.top, Theme.Spacing.xs)
                        .tabReveal(tab: 3, order: 9)

                    sectionLabel("PUTTING")
                        .tabReveal(tab: 3, order: 10)
                    puttingCard.padding(.top, Theme.Spacing.xs)
                        .tabReveal(tab: 3, order: 11)

                    sectionLabel("HAZARDS")
                        .tabReveal(tab: 3, order: 12)
                    hazardsCard.padding(.top, Theme.Spacing.xs)
                        .tabReveal(tab: 3, order: 13)
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await loadRounds() }
        .onAppear {
            syncRadarAnimation(for: isActiveTab)
        }
        .onChange(of: isActiveTab) { _, isActive in
            syncRadarAnimation(for: isActive)
        }
    }

    private func loadRounds() async {
        do {
            let courseRows = try await DataService.shared.fetchCourses()
            let roundRows = try await DataService.shared.fetchRounds()
            let courseMap = Dictionary(uniqueKeysWithValues: courseRows.map { ($0.courseId, $0) })
            allRounds = roundRows.compactMap { row in
                guard let course = courseMap[row.courseId] else { return nil }
                return CompletedRound(from: row, course: course)
            }
        } catch {
            allRounds = []
        }
        syncRadarAnimation(for: isActiveTab)
    }

    private func syncRadarAnimation(for isActive: Bool) {
        radarAnimationToken += 1
        let token = radarAnimationToken
        radarAnimated = false

        guard isActive else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard token == radarAnimationToken else { return }
            radarAnimated = true
        }
    }

    // MARK: – Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.captionSmall)
            .foregroundStyle(Theme.Colors.textTertiary)
            .kerning(1.0)
            .padding(.top, Theme.Spacing.xl + 2)
    }

    // MARK: – Hero card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accentLight],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.08), .clear],
                                     startPoint: .topLeading, endPoint: .center))
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "gauge.medium")
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(.white.opacity(0.40))
                Spacer()
                Text(handicap.map { String(format: "%.1f", $0) } ?? "—")
                    .font(Theme.Typography.display)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .padding(.bottom, Theme.Spacing.xxxs)
                Text("Handicap Index")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.bottom, Theme.Spacing.md)
                HStack(spacing: 0) {
                    heroMiniStat(value: "\(avgScore)", label: "Avg Score")
                    Rectangle().fill(.white.opacity(0.20)).frame(width: 1, height: 26).padding(.trailing, Theme.Spacing.md)
                    heroMiniStat(value: "\(bestScore)", label: "Best Score")
                    Rectangle().fill(.white.opacity(0.20)).frame(width: 1, height: 26).padding(.trailing, Theme.Spacing.md)
                    heroMiniStat(value: "\(roundCount)", label: "Rounds")
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: isImproving ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(isImproving ? "Improving" : "Trending up")
                            .font(Theme.Typography.captionSmall)
                    }
                    .foregroundStyle(isImproving
                        ? Theme.Colors.success
                        : Theme.Colors.warning)
                }
            }
            .padding(Theme.Spacing.lg + 2)
        }
        .frame(maxWidth: .infinity).frame(height: 218)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .themeShadow(Theme.Shadow.prominent)
    }

    private func heroMiniStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
            Text(value).font(Theme.Typography.title2).foregroundStyle(.white).monospacedDigit()
                .contentTransition(.numericText())
            Text(label).font(Theme.Typography.captionSmall).foregroundStyle(.white.opacity(0.42))
        }
        .padding(.trailing, Theme.Spacing.md)
    }

    // MARK: – Radar card

    private var radarCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Complete Game Profile")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Six core areas normalized so higher always means stronger performance.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            RadarChartView(metrics: completeGameMetrics, radarAnimated: radarAnimated)
                .frame(height: 260)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(completeGameMetrics) { metric in
                    radarMetricCell(metric)
                }
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func radarMetricCell(_ metric: RadarMetric) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(metric.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text(metric.label)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(Int((metric.score * 100).rounded()))")
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()
                }
                Text(metric.detail)
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm - 1)
        .background(Theme.Colors.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm + 3, style: .continuous))
    }

    private func normalizedInverse(_ value: Double, best: Double, worst: Double) -> Double {
        guard worst > best else { return 0 }
        return max(0, min(1, (worst - value) / (worst - best)))
    }

    // MARK: – Distribution card

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geo in
                let w = geo.size.width
                let t = CGFloat(max(distTotal, 1))
                HStack(spacing: 2) {
                    if dist.under > 0 {
                        Theme.Colors.success.frame(width: w * CGFloat(dist.under) / t)
                    }
                    Theme.Colors.textPrimary.frame(width: w * CGFloat(dist.pars) / t)
                    Theme.Colors.textTertiary.frame(width: w * CGFloat(dist.bogeys) / t)
                    if dist.doubles > 0 {
                        Theme.Colors.error.frame(width: w * CGFloat(dist.doubles) / t)
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(spacing: 9) {
                distRow(color: Theme.Colors.success,       label: "Under Par", count: dist.under)
                distRow(color: Theme.Colors.textPrimary,   label: "Par",       count: dist.pars)
                distRow(color: Theme.Colors.textTertiary,  label: "Bogey",     count: dist.bogeys)
                distRow(color: Theme.Colors.error,         label: "Double+",   count: dist.doubles)
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func distRow(color: Color, label: String, count: Int) -> some View {
        let pct = distTotal > 0 ? Int((Double(count) / Double(distTotal) * 100).rounded()) : 0
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text("\(count)").font(Theme.Typography.caption).fontWeight(.semibold).foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit().frame(width: 28, alignment: .trailing)
            Text("\(pct)%").font(Theme.Typography.captionSmall).foregroundStyle(Theme.Colors.textTertiary)
                .monospacedDigit().frame(width: 34, alignment: .trailing)
        }
    }

    // MARK: – Accuracy card

    private var accuracyCard: some View {
        HStack(alignment: .top, spacing: 0) {
            shotAccuracyPanel(
                title: "TEE SHOT",
                pctValue: firText,
                pctLabel: "Fairways Hit",
                dirs: teeDirs,
                missTotal: teeMisses.total
            )
            Rectangle().fill(Theme.Colors.whisperBorder).frame(width: 1)
            shotAccuracyPanel(
                title: "APPROACH",
                pctValue: girText,
                pctLabel: "Greens in Reg",
                dirs: appDirs,
                missTotal: appMisses.total
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
        dirs: DirFractions,
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
                    .foregroundStyle(pctColor(pctValue))
                    .monospacedDigit()
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: pctLabel == "Greens in Reg" ? "flag.fill" : "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(pctLabel)
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, Theme.Spacing.md)

            if missTotal > 0 {
                Text("miss tendency")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .kerning(0.4)
                    .padding(.bottom, 10)

                missCompass(dirs: dirs)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pctColor(_ text: String) -> Color {
        let num = Int(text.replacingOccurrences(of: "%", with: "")) ?? 0
        if num >= 60 { return Theme.Colors.success }
        if num >= 40 { return Theme.Colors.textPrimary }
        return Theme.Colors.error
    }

    private func missCompass(dirs: DirFractions) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            dirBubble(label: "Long", fraction: dirs.long)
            HStack(spacing: Theme.Spacing.xxs + 2) {
                dirBubble(label: "Left", fraction: dirs.left)
                compassRose
                dirBubble(label: "Right", fraction: dirs.right)
            }
            dirBubble(label: "Short", fraction: dirs.short)
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

    private func dirBubble(label: String, fraction: Double) -> some View {
        let pct = Int((fraction * 100).rounded())
        let alpha = 0.18 + min(fraction, 1.0) * 0.82
        let icon: String = switch label {
        case "Left":  "arrow.left"
        case "Right": "arrow.right"
        case "Long":  "arrow.up"
        case "Short": "arrow.down"
        default:      "circle"
        }
        return VStack(spacing: 1) {
            Text("\(pct)%")
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
            .foregroundStyle(Theme.Colors.textPrimary.opacity(alpha * 0.60))
        }
        .frame(width: 46)
    }

    // MARK: – Par type card

    private var parTypeCard: some View {
        let p3 = avgVsPar(3); let p4 = avgVsPar(4); let p5 = avgVsPar(5)
        let maxVal = max(p3, p4, p5, 0.01)
        return VStack(spacing: 0) {
            parTypeRow(label: "Par 3", avg: p3, maxVal: maxVal)
            Divider().opacity(0.5)
            parTypeRow(label: "Par 4", avg: p4, maxVal: maxVal)
            Divider().opacity(0.5)
            parTypeRow(label: "Par 5", avg: p5, maxVal: maxVal)
        }
        .padding(.horizontal, Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func parTypeRow(label: String, avg: Double, maxVal: Double) -> some View {
        let fraction = CGFloat(max(0, avg / maxVal))
        let valueText = avg >= 0 ? String(format: "+%.2f", avg) : String(format: "%.2f", avg)
        let barColor: Color = avg <= 0.3
            ? Theme.Colors.success
            : avg <= 0.6
                ? Theme.Colors.warning
                : Theme.Colors.error
        let valueColor: Color = avg <= 0.3
            ? Theme.Colors.success
            : avg <= 0.6
                ? Theme.Colors.warning
                : Theme.Colors.error
        return HStack(spacing: Theme.Spacing.sm) {
            Text(label).font(Theme.Typography.caption).fontWeight(.semibold).foregroundStyle(Theme.Colors.textPrimary).frame(width: 46, alignment: .leading)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Theme.Colors.whisperBorder).frame(height: 7)
                RoundedRectangle(cornerRadius: 4).fill(barColor)
                    .frame(maxWidth: .infinity, maxHeight: 7).scaleEffect(x: fraction, y: 1, anchor: .leading)
            }
            Text(valueText).font(Theme.Typography.caption).fontWeight(.semibold).foregroundStyle(valueColor)
                .monospacedDigit().frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    // MARK: – Hazards card

    private var hazardsCard: some View {
        HStack(spacing: 0) {
            hazardCell(icon: "figure.golf", label: "Bunker", avg: avgBunkerPerRound, color: Theme.Colors.bunker)
            Divider().frame(height: 44)
            hazardCell(icon: "drop.fill",   label: "Water",  avg: avgWaterPerRound, color: Theme.Colors.water)
            Divider().frame(height: 44)
            hazardCell(icon: "xmark",       label: "OOB",    avg: avgOOBPerRound, color: Theme.Colors.error)
        }
        .padding(.vertical, Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func hazardCell(icon: String, label: String, avg: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(color.opacity(0.65))
            Text(String(format: "%.1f", avg))
                .font(Theme.Typography.title)
                .foregroundStyle(avg > 1.0 ? color : Theme.Colors.textPrimary)
                .monospacedDigit()
            VStack(spacing: 1) {
                Text(label)
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text("per round")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Putting card

    private var puttingCard: some View {
        HStack(spacing: 0) {
            puttingCell(value: String(format: "%.1f", avgPuttsPerRound), label: "Per Round", color: Theme.Colors.textPrimary)
            Divider().frame(height: 32)
            puttingCell(value: String(format: "%.2f", avgPuttsPerHole), label: "Per Hole",
                        color: avgPuttsPerHole <= 1.8 ? Theme.Colors.success : Theme.Colors.textPrimary)
            Divider().frame(height: 32)
            puttingCell(value: "\(threePuttCount)", label: "3-Putts",
                        color: threePuttCount > 0 ? Theme.Colors.error : Theme.Colors.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func puttingCell(value: String, label: String, color: Color = Theme.Colors.textPrimary) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value).font(Theme.Typography.title).foregroundStyle(color).monospacedDigit()
            Text(label).font(Theme.Typography.captionSmall).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RadarChartView: View {
    let metrics: [RadarMetric]
    var radarAnimated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.34
            let labelRadius = radius + 30

            ZStack {
                ForEach(1...4, id: \.self) { level in
                    radarPolygon(
                        center: center,
                        radius: radius * CGFloat(level) / 4,
                        values: Array(repeating: 1, count: metrics.count)
                    )
                    .stroke(Theme.Colors.whisperBorder.opacity(level == 4 ? 1.0 : 0.5), lineWidth: 1)
                }

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: axisPoint(center: center, radius: radius, index: index, count: metrics.count, value: 1))
                    }
                    .stroke(Theme.Colors.whisperBorder, lineWidth: 1)

                    let labelPoint = axisPoint(center: center, radius: labelRadius, index: index, count: metrics.count, value: 1)
                    VStack(spacing: Theme.Spacing.xxxs) {
                        Text(metric.label)
                            .font(Theme.Typography.captionSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(Int((metric.score * 100).rounded()))")
                            .font(Theme.Typography.captionSmall)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .monospacedDigit()
                    }
                    .frame(width: 70)
                    .position(labelPoint)
                }

                radarPolygon(center: center, radius: radius, values: metrics.map(\.score))
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.approach.opacity(0.28),
                                Theme.Colors.driving.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(radarAnimated ? 1 : 0)
                    .animation(Theme.Animation.bouncy.delay(0.3), value: radarAnimated)

                radarPolygon(center: center, radius: radius, values: metrics.map(\.score))
                    .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                    .scaleEffect(radarAnimated ? 1 : 0)
                    .animation(Theme.Animation.bouncy.delay(0.3), value: radarAnimated)

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Circle()
                        .fill(metric.color)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(axisPoint(center: center, radius: radius, index: index, count: metrics.count, value: metric.score))
                        .scaleEffect(radarAnimated ? 1 : 0)
                        .animation(Theme.Animation.bouncy.delay(0.35 + Double(index) * 0.04), value: radarAnimated)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func radarPolygon(center: CGPoint, radius: CGFloat, values: [Double]) -> Path {
        Path { path in
            guard !values.isEmpty else { return }

            for index in values.indices {
                let point = axisPoint(
                    center: center,
                    radius: radius,
                    index: index,
                    count: values.count,
                    value: values[index]
                )

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.closeSubpath()
        }
    }

    private func axisPoint(
        center: CGPoint,
        radius: CGFloat,
        index: Int,
        count: Int,
        value: Double
    ) -> CGPoint {
        let angle = (-Double.pi / 2) + (Double(index) * (Double.pi * 2 / Double(max(count, 1))))
        let scaledRadius = radius * CGFloat(max(0, min(1, value)))

        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * scaledRadius,
            y: center.y + CGFloat(sin(angle)) * scaledRadius
        )
    }
}
