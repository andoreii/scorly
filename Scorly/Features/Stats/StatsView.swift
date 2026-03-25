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
    @State private var allRounds: [CompletedRound] = []

    private var rounds: [CompletedRound] {
        Array(allRounds.sorted { $0.date > $1.date }.prefix(20))
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
                color: .black
            ),
            RadarMetric(
                label: "Driving",
                score: firFraction,
                detail: totalFIRApp > 0 ? "\(Int((firFraction * 100).rounded()))% FIR" : "No FIR data",
                color: Color(red: 0.14, green: 0.35, blue: 0.72)
            ),
            RadarMetric(
                label: "Approach",
                score: girFraction,
                detail: totalHoles > 0 ? "\(Int((girFraction * 100).rounded()))% GIR" : "No GIR data",
                color: Color(red: 0.486, green: 0.718, blue: 0.498)
            ),
            RadarMetric(
                label: "Short Game",
                score: shortGameScore,
                detail: bunkerOpportunityCount > 0
                    ? "\(Int((shortGameScore * 100).rounded()))% combined"
                    : (missedGIRCount > 0 ? "\(Int((upAndDownRate * 100).rounded()))% up-and-down" : "No short game data"),
                color: Color(red: 0.82, green: 0.65, blue: 0.38)
            ),
            RadarMetric(
                label: "Putting",
                score: puttingScore,
                detail: totalHoles > 0 ? String(format: "%.2f putts/hole", avgPuttsPerHole) : "No putting data",
                color: Color(red: 0.39, green: 0.34, blue: 0.85)
            ),
            RadarMetric(
                label: "Trouble",
                score: troubleAvoidanceScore,
                detail: totalHoles > 0 ? String(format: "%.2f trouble/hole", troubleRatePerHole) : "No trouble data",
                color: Color(red: 0.88, green: 0.28, blue: 0.24)
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
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    Text("Stats")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.bottom, 20)

                    heroCard

                    sectionLabel("COMPLETE GAME")
                    radarCard.padding(.top, 8)

                    sectionLabel("SCORING")
                    distributionCard.padding(.top, 8)

                    sectionLabel("ACCURACY")
                    accuracyCard.padding(.top, 8)

                    sectionLabel("PERFORMANCE")
                    parTypeCard.padding(.top, 8)

                    sectionLabel("PUTTING")
                    puttingCard.padding(.top, 8)

                    sectionLabel("HAZARDS")
                    hazardsCard.padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await loadRounds() }
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
    }

    // MARK: – Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black.opacity(0.32))
            .kerning(1.0)
            .padding(.top, 26)
    }

    // MARK: – Hero card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color.black, Color(red: 0.14, green: 0.14, blue: 0.16)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.08), .clear],
                                     startPoint: .topLeading, endPoint: .center))
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)

            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.40))
                Spacer()
                Text(handicap.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.bottom, 2)
                Text("Handicap Index")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.bottom, 16)
                HStack(spacing: 0) {
                    heroMiniStat(value: "\(avgScore)", label: "Avg Score")
                    Rectangle().fill(.white.opacity(0.20)).frame(width: 1, height: 26).padding(.trailing, 16)
                    heroMiniStat(value: "\(bestScore)", label: "Best Score")
                    Rectangle().fill(.white.opacity(0.20)).frame(width: 1, height: 26).padding(.trailing, 16)
                    heroMiniStat(value: "\(roundCount)", label: "Rounds")
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: isImproving ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(isImproving ? "Improving" : "Trending up")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isImproving
                        ? Color(red: 0.35, green: 0.90, blue: 0.55)
                        : Color(red: 1.0,  green: 0.65, blue: 0.30))
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity).frame(height: 218)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
    }

    private func heroMiniStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).monospacedDigit()
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.42))
        }
        .padding(.trailing, 16)
    }

    // MARK: – Radar card

    private var radarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Complete Game Profile")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                Text("Six core areas normalized so higher always means stronger performance.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
            }

            RadarChartView(metrics: completeGameMetrics)
                .frame(height: 260)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(completeGameMetrics) { metric in
                    radarMetricCell(metric)
                }
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func radarMetricCell(_ metric: RadarMetric) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(metric.color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metric.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                    Spacer(minLength: 0)
                    Text("\(Int((metric.score * 100).rounded()))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                }
                Text(metric.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.42))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                        Color(red: 0.353, green: 0.620, blue: 0.365).frame(width: w * CGFloat(dist.under) / t)
                    }
                    Color.black.frame(width: w * CGFloat(dist.pars) / t)
                    Color.black.opacity(0.28).frame(width: w * CGFloat(dist.bogeys) / t)
                    if dist.doubles > 0 {
                        Color(red: 0.70, green: 0.15, blue: 0.15).frame(width: w * CGFloat(dist.doubles) / t)
                    }
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(spacing: 9) {
                distRow(color: Color(red: 0.353, green: 0.620, blue: 0.365), label: "Under Par", count: dist.under)
                distRow(color: .black,                                      label: "Par",       count: dist.pars)
                distRow(color: .black.opacity(0.28),                        label: "Bogey",     count: dist.bogeys)
                distRow(color: Color(red: 0.70, green: 0.15, blue: 0.15),  label: "Double+",   count: dist.doubles)
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func distRow(color: Color, label: String, count: Int) -> some View {
        let pct = distTotal > 0 ? Int((Double(count) / Double(distTotal) * 100).rounded()) : 0
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.black)
            Spacer()
            Text("\(count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.black)
                .monospacedDigit().frame(width: 28, alignment: .trailing)
            Text("\(pct)%").font(.system(size: 12, weight: .medium)).foregroundStyle(.black.opacity(0.38))
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
            Rectangle().fill(Color.black.opacity(0.06)).frame(width: 1)
            shotAccuracyPanel(
                title: "APPROACH",
                pctValue: girText,
                pctLabel: "Greens in Reg",
                dirs: appDirs,
                missTotal: appMisses.total
            )
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.black.opacity(0.35))
                .kerning(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            VStack(spacing: 2) {
                Text(pctValue)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(pctColor(pctValue))
                    .monospacedDigit()
                HStack(spacing: 4) {
                    Image(systemName: pctLabel == "Greens in Reg" ? "flag.fill" : "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.35))
                    Text(pctLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.black.opacity(0.40))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            if missTotal > 0 {
                Text("miss tendency")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.black.opacity(0.28))
                    .kerning(0.4)
                    .padding(.bottom, 10)

                missCompass(dirs: dirs)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pctColor(_ text: String) -> Color {
        let num = Int(text.replacingOccurrences(of: "%", with: "")) ?? 0
        if num >= 60 { return Color(red: 0.353, green: 0.620, blue: 0.365) }
        if num >= 40 { return .black }
        return Color(red: 0.70, green: 0.15, blue: 0.15)
    }

    private func missCompass(dirs: DirFractions) -> some View {
        VStack(spacing: 4) {
            dirBubble(label: "Long", fraction: dirs.long)
            HStack(spacing: 6) {
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
                .stroke(Color.black.opacity(0.14), lineWidth: 1.5)
                .frame(width: 30, height: 30)
            Circle()
                .fill(Color.black.opacity(0.06))
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.black.opacity(alpha))
                .monospacedDigit()
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 7, weight: .bold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Color.black.opacity(alpha * 0.60))
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
        .padding(.horizontal, 18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func parTypeRow(label: String, avg: Double, maxVal: Double) -> some View {
        let fraction = CGFloat(max(0, avg / maxVal))
        let valueText = avg >= 0 ? String(format: "+%.2f", avg) : String(format: "%.2f", avg)
        let barColor: Color = avg <= 0.3
            ? Color(red: 0.353, green: 0.620, blue: 0.365)
            : avg <= 0.6
                ? Color(red: 0.94, green: 0.67, blue: 0.16)
                : Color(red: 0.70, green: 0.15, blue: 0.15)
        let valueColor: Color = avg <= 0.3
            ? Color(red: 0.353, green: 0.620, blue: 0.365)
            : avg <= 0.6
                ? Color(red: 0.72, green: 0.52, blue: 0.00)
                : Color(red: 0.70, green: 0.15, blue: 0.15)
        return HStack(spacing: 12) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(.black).frame(width: 46, alignment: .leading)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.07)).frame(height: 7)
                RoundedRectangle(cornerRadius: 4).fill(barColor)
                    .frame(maxWidth: .infinity, maxHeight: 7).scaleEffect(x: fraction, y: 1, anchor: .leading)
            }
            Text(valueText).font(.system(size: 13, weight: .semibold)).foregroundStyle(valueColor)
                .monospacedDigit().frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 14)
    }

    // MARK: – Hazards card

    private var hazardsCard: some View {
        HStack(spacing: 0) {
            hazardCell(icon: "figure.golf", label: "Bunker", avg: avgBunkerPerRound, color: Color(red: 0.82, green: 0.65, blue: 0.38))
            Divider().frame(height: 44)
            hazardCell(icon: "drop.fill",   label: "Water",  avg: avgWaterPerRound, color: Color(red: 0.36, green: 0.57, blue: 0.90))
            Divider().frame(height: 44)
            hazardCell(icon: "xmark",       label: "OOB",    avg: avgOOBPerRound, color: Color(red: 0.88, green: 0.28, blue: 0.24))
        }
        .padding(.vertical, 18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func hazardCell(icon: String, label: String, avg: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color.opacity(0.65))
            Text(String(format: "%.1f", avg))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(avg > 1.0 ? color : .black)
                .monospacedDigit()
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
                Text("per round")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.black.opacity(0.28))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: – Putting card

    private var puttingCard: some View {
        HStack(spacing: 0) {
            puttingCell(value: String(format: "%.1f", avgPuttsPerRound), label: "Per Round", color: .black)
            Divider().frame(height: 32)
            puttingCell(value: String(format: "%.2f", avgPuttsPerHole), label: "Per Hole",
                        color: avgPuttsPerHole <= 1.8 ? Color(red: 0.353, green: 0.620, blue: 0.365) : .black)
            Divider().frame(height: 32)
            puttingCell(value: "\(threePuttCount)", label: "3-Putts",
                        color: threePuttCount > 0 ? Color(red: 0.70, green: 0.15, blue: 0.15) : .black)
        }
        .padding(.vertical, 16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func puttingCell(value: String, label: String, color: Color = .black) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.black.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RadarChartView: View {
    let metrics: [RadarMetric]

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
                    .stroke(Color.black.opacity(level == 4 ? 0.12 : 0.06), lineWidth: 1)
                }

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: axisPoint(center: center, radius: radius, index: index, count: metrics.count, value: 1))
                    }
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)

                    let labelPoint = axisPoint(center: center, radius: labelRadius, index: index, count: metrics.count, value: 1)
                    VStack(spacing: 2) {
                        Text(metric.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(Int((metric.score * 100).rounded()))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.45))
                            .monospacedDigit()
                    }
                    .frame(width: 70)
                    .position(labelPoint)
                }

                radarPolygon(center: center, radius: radius, values: metrics.map(\.score))
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.28),
                                Color(red: 0.14, green: 0.35, blue: 0.72).opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                radarPolygon(center: center, radius: radius, values: metrics.map(\.score))
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Circle()
                        .fill(metric.color)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .position(axisPoint(center: center, radius: radius, index: index, count: metrics.count, value: metric.score))
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
