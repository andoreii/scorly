//
// RoundTrackerView.swift
// Hole-by-hole round tracker — redesigned for on-course use.
//

import SwiftUI

// Player handicap — cached in UserDefaults, synced from Supabase on profile load
private var playerHandicap: Int {
    UserDefaults.standard.integer(forKey: "cachedPlayerHandicap")
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Hole stat model

struct HoleStat: Equatable, Codable {
    var strokes: Int
    var putts: Int = 0
    init(strokes: Int = 0) { self.strokes = strokes }
    var teeShot: String? = nil
    var approach: String? = nil
    var teeClub: String = ""
    var approachClub: String = ""
    var penaltyStrokes: Int = 0
    var upAndDownSuccess: Bool = false
    var sandSaveSuccess: Bool = false

    // Auto-derived — never stored separately
    var outOfBoundsCount: Int {
        let ob = ["Out Left","Out Right","Out Short","Out Long"]
        return (teeShot.map { ob.contains($0) ? 1 : 0 } ?? 0)
             + (approach.map { ob.contains($0) ? 1 : 0 } ?? 0)
    }
    var hazardCount: Int {
        let w = ["Left water","Right water","Long Water","Short water"]
        return (teeShot.map { w.contains($0) ? 1 : 0 } ?? 0)
             + (approach.map { w.contains($0) ? 1 : 0 } ?? 0)
    }
    func greenInReg(par: Int) -> Bool {
        guard strokes > 0, putts > 0, putts <= strokes else { return false }
        return approach == "Green" && (strokes - putts) <= par - 2
    }
    func fairwayInReg(par: Int) -> Bool { teeShot == "Fairway" && par > 3 }
    var threePutt: Bool { putts >= 3 }
}

// MARK: - Main view

struct RoundTrackerView: View {

    let course: Course
    let datePlayed: Date
    let holesOption: RoundSetupView.HolesOption
    let teeIndex: Int
    let notes: String
    let conditions: [String]
    let temperature: Int?
    let roundType: String
    let roundFormat: String
    let transport: String
    let mentalState: Int

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore

    @State private var currentHoleIndex = 0
    @State private var holeStats: [HoleStat]
    @State private var teeShotCategory: ShotCategory? = nil
    @State private var approachCategory: ShotCategory? = nil
    @State private var showScorecard = false
    @State private var showDeleteConfirm = false
    @State private var showSummary = false

    private let holes: [CourseHole]

    // MARK: Supporting types

    enum ShotCategory: Equatable {
        case hit, missed, bunker, trouble
        var color: Color {
            switch self {
            case .hit:     return Theme.Colors.success
            case .missed:  return Theme.Colors.warning
            case .bunker:  return Theme.Colors.bunker
            case .trouble: return Theme.Colors.error
            }
        }
    }

    // MARK: Init

    init(
        course: Course,
        datePlayed: Date = .now,
        holesOption: RoundSetupView.HolesOption,
        teeIndex: Int,
        notes: String = "",
        conditions: [String] = [],
        temperature: Int? = nil,
        roundType: String = "",
        roundFormat: String = "",
        transport: String = "",
        mentalState: Int = 5
    ) {
        self.course      = course
        self.datePlayed  = datePlayed
        self.holesOption = holesOption
        self.teeIndex    = teeIndex
        self.notes       = notes
        self.conditions  = conditions
        self.temperature = temperature
        self.roundType   = roundType
        self.roundFormat = roundFormat
        self.transport   = transport
        self.mentalState = mentalState
        let all = course.holes
        switch holesOption {
        case .front9: holes = Array(all.prefix(9))
        case .back9:  holes = Array(all.suffix(9))
        case .full18: holes = all
        }
        _holeStats = State(initialValue: holes.map { HoleStat(strokes: $0.par) })
    }

    /// Resume an existing in-progress round from the home screen.
    init(resumingFrom round: ActiveRoundData) {
        self.course      = round.course
        self.datePlayed  = round.datePlayed
        self.holesOption = round.holesOption
        self.teeIndex    = round.teeIndex
        self.notes       = round.notes
        self.conditions  = round.conditions
        self.temperature = round.temperature
        self.roundType   = round.roundType
        self.roundFormat = round.roundFormat
        self.transport   = round.transport
        self.mentalState = round.mentalState
        self.holes       = round.holes
        _currentHoleIndex = State(initialValue: round.currentHoleIndex)
        _holeStats        = State(initialValue: round.holeStats)
    }

    // MARK: Computed

    private var hole: CourseHole { holes[currentHoleIndex] }
    private var stat: HoleStat   { holeStats[currentHoleIndex] }
    private var isLastHole: Bool { currentHoleIndex == holes.count - 1 }

    private func holePlayed(_ s: HoleStat) -> Bool { s.teeShot != nil || s.putts > 0 }

    private var runningScore: Int {
        // Unplayed holes default to par (delta 0), so no filter needed —
        // the score updates the instant you touch the strokes stepper.
        holeStats.enumerated().reduce(0) { sum, pair in
            sum + pair.element.strokes - holes[pair.offset].par
        }
    }
    private var showApproach: Bool { stat.teeShot != nil && stat.teeShot != "Green" }
    private var showExtras: Bool   { holePlayed(stat) }
    private var holeComplete: Bool { holePlayed(stat) }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.sm) {
                        holeInfoCard
                        scoreCard
                        shotFlowCard
                        if showExtras {
                            extrasCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .animation(Theme.Animation.smooth, value: showExtras)
                    .padding(.horizontal, Theme.Spacing.pageHorizontal)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, 108)
                    .id(currentHoleIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(Theme.Animation.smooth, value: currentHoleIndex)
                }
                .scrollBounceBehavior(.basedOnSize)
                .contentMargins(.top, 0, for: .scrollContent)
            }

            if showDeleteConfirm {
                DeleteRoundPopup(
                    onDelete: {
                        withAnimation(Theme.Animation.snappy) { showDeleteConfirm = false }
                        roundStore.deleteRoundAndExit()
                    },
                    onCancel: {
                        withAnimation(Theme.Animation.snappy) { showDeleteConfirm = false }
                    }
                )
                .zIndex(99)
                .transition(.opacity)
                .animation(Theme.Animation.snappy, value: showDeleteConfirm)
            }

            bottomNav
                .background(
                    Theme.Colors.canvas
                        .shadow(color: Theme.Shadow.medium.color, radius: Theme.Shadow.medium.radius, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            roundStore.startRound(
                course: course,
                datePlayed: datePlayed,
                holes: holes,
                holesOption: holesOption,
                teeIndex: teeIndex,
                notes: notes,
                conditions: conditions,
                temperature: temperature,
                roundType: roundType,
                roundFormat: roundFormat,
                transport: transport,
                mentalState: mentalState
            )
            restoreCategories()
        }
        .onChange(of: currentHoleIndex) { _ in
            restoreCategories()
            roundStore.update(currentHoleIndex: currentHoleIndex, holeStats: holeStats)
        }
        .onChange(of: holeStats) { _ in
            roundStore.update(currentHoleIndex: currentHoleIndex, holeStats: holeStats)
        }
        .sheet(isPresented: $showScorecard) {
            ScorecardSheet(
                holes: holes,
                holeStats: holeStats,
                teeIndex: teeIndex,
                currentHoleIndex: currentHoleIndex,
                onSelectHole: { index in
                    withAnimation(Theme.Animation.snappy) { currentHoleIndex = index }
                    showScorecard = false
                }
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showSummary) {
            RoundSummaryView(
                course: course,
                holes: holes,
                holeStats: holeStats,
                teeIndex: teeIndex
            )
            .environmentObject(roundStore)
        }
    }

    private func restoreCategories() {
        teeShotCategory = category(from: stat.teeShot)
        approachCategory = category(from: stat.approach)
    }

    private func category(from result: String?) -> ShotCategory? {
        guard let r = result else { return nil }
        if r == "Fairway" || r == "Green" { return .hit }
        if ["Left","Right","Short","Long"].contains(r) { return .missed }
        if r.hasPrefix("Bunker") { return .bunker }
        return .trouble
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { roundStore.saveAndExit() }) {
                Image(systemName: "chevron.left")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Theme.Colors.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
            }
            .buttonStyle(ScorlyPressStyle())

            Spacer()

            VStack(spacing: Theme.Spacing.xxxs) {
                Text(course.name)
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Hole \(hole.number) of \(holes.count)")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer()

            HStack(spacing: Theme.Spacing.xs) {
                Button(action: { showScorecard = true }) {
                    Image(systemName: "tablecells")
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(Theme.Colors.surface, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
                }
                .buttonStyle(ScorlyPressStyle())

                Button(action: {
                    withAnimation(Theme.Animation.snappy) { showDeleteConfirm = true }
                }) {
                    Image(systemName: "trash")
                        .font(Theme.Typography.bodySemibold)
                        .foregroundStyle(Theme.Colors.error)
                        .frame(width: 42, height: 42)
                        .background(Theme.Colors.surface, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
                }
                .buttonStyle(ScorlyPressStyle())
            }
        }
        .padding(.horizontal, Theme.Spacing.pageHorizontal)
        .frame(height: 56)
    }

    // MARK: - Hole info card

    private var holeInfoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accentLight.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                // Top row: hole number + score badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("HOLE")
                            .font(Theme.Typography.captionSmall)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(1.4)
                        Text("\(hole.number)")
                            .font(.system(size: 64, weight: .black))
                            .foregroundStyle(.white)
                            .lineSpacing(0)
                            .padding(.top, -Theme.Spacing.xxs)
                            .contentTransition(.numericText(value: Double(hole.number)))
                            .animation(Theme.Animation.bouncy, value: hole.number)
                    }

                    Spacer()

                    // Always show running score badge
                    let score = runningScore
                    let scoreLabel = score == 0 ? "E" : (score > 0 ? "+\(score)" : "\(score)")
                    let scoreBg: Color = score < 0
                        ? Theme.Colors.warning                                // under par → yellow
                        : score == 0 ? Color.white.opacity(0.15)              // even → neutral
                        : score < playerHandicap
                            ? Theme.Colors.success                            // within handicap → green
                            : Theme.Colors.error                              // over handicap → red
                    VStack(spacing: 3) {
                        Text(scoreLabel)
                            .font(Theme.Typography.monoLarge)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(score)))
                            .animation(Theme.Animation.bouncy, value: score)
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(1.2)
                    }
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(scoreBg))
                    .animation(Theme.Animation.smooth, value: scoreBg)
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.cardPadding)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .padding(.horizontal, Theme.Spacing.pageHorizontal)
                    .padding(.top, Theme.Spacing.sm)

                // Stat pills row
                HStack(spacing: Theme.Spacing.xs) {
                    holeStatPill(value: "Par \(hole.par)", icon: "flag.fill")
                    if let yds = hole.yardages[safe: teeIndex] {
                        holeStatPill(value: "\(yds) yds", icon: "arrow.up.forward")
                    }
                    holeStatPill(value: "Hcp \(hole.handicap)", icon: "bolt.fill")
                    holeStatPill(value: "\(stat.strokes)", icon: "figure.golf")
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.vertical, 14)
            }
        }
        .themeShadow(Theme.Shadow.prominent)
        .animation(Theme.Animation.smooth, value: currentHoleIndex)
    }

    private func holeStatPill(value: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(Theme.Typography.captionSmall)
            Text(value)
                .font(Theme.Typography.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, Theme.Spacing.xs + 2)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    // MARK: - Score card

    private var scoreCard: some View {
        formCard {
            VStack(spacing: 0) {

                // ── Strokes — centered stepper ────────────────────────────
                VStack(spacing: 6) {
                    sectionLabel(icon: "figure.golf", title: "Strokes")
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack(spacing: 0) {
                        Button(action: {
                            if holeStats[currentHoleIndex].strokes > 1 {
                                holeStats[currentHoleIndex].strokes -= 1
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(Theme.Typography.title)
                                .foregroundStyle(stat.strokes <= 1 ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                        .fill(Theme.Colors.textPrimary.opacity(0.05))
                                )
                        }
                        .buttonStyle(ScorlyPressStyle())
                        .disabled(stat.strokes <= 1)

                        Text("\(stat.strokes)")
                            .font(Theme.Typography.display)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(stat.strokes)))
                            .animation(Theme.Animation.bouncy, value: stat.strokes)

                        Button(action: { holeStats[currentHoleIndex].strokes += 1 }) {
                            Image(systemName: "plus")
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                        .fill(Theme.Colors.textPrimary.opacity(0.05))
                                )
                        }
                        .buttonStyle(ScorlyPressStyle())
                    }

                    // Score-to-par label for this hole
                    let holeDelta = stat.strokes - hole.par
                    let deltaLabel = holeDelta == 0 ? "Even" : (holeDelta > 0 ? "+\(holeDelta)" : "\(holeDelta)")
                    // Handicap strokes: player gets a stroke on holes where hole handicap <= player handicap
                    let hcpStrokes = hole.handicap <= playerHandicap ? 1 : 0
                    let adjustedDelta = holeDelta - hcpStrokes
                    let deltaColor: Color = holeDelta < 0
                        ? Theme.Colors.warning                                 // under par → amber
                        : adjustedDelta <= 0 ? Theme.Colors.success            // within handicap → green
                        : holeDelta == 0 ? Theme.Colors.textTertiary           // even, no stroke → neutral
                        : Theme.Colors.error                                   // over handicap → red
                    Text(deltaLabel)
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(deltaColor)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(holeDelta)))
                        .animation(Theme.Animation.bouncy, value: holeDelta)
                        .animation(Theme.Animation.smooth, value: deltaColor)
                }
                .padding(.bottom, Theme.Spacing.md)

                // ── Divider ───────────────────────────────────────────────
                divLine

                // ── Putts — dot picker ────────────────────────────────────
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    sectionLabel(icon: "arrow.right.to.line", title: "Putts")
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(1...5, id: \.self) { n in
                            Button(action: {
                                holeStats[currentHoleIndex].putts = stat.putts == n ? 0 : n
                            }) {
                                Circle()
                                    .fill(n <= stat.putts ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.09))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text("\(n)")
                                            .font(Theme.Typography.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(n <= stat.putts ? .white : Theme.Colors.textTertiary)
                                    )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: stat.putts)
                        }
                        Spacer()
                        if stat.putts > 0 {
                            Text("\(stat.putts) putt\(stat.putts == 1 ? "" : "s")")
                                .font(Theme.Typography.captionSmall)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .contentTransition(.numericText(value: Double(stat.putts)))
                                .animation(Theme.Animation.bouncy, value: stat.putts)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.top, Theme.Spacing.md)
            }
        }
    }

    // MARK: - Shot flow card

    private var shotFlowCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 0) {
                // ── Tee shot ──────────────────────────────────────────────
                sectionLabel(icon: "arrow.up.right.circle.fill", title: "Tee Shot")
                    .padding(.bottom, Theme.Spacing.xs + 2)

                shotPicker(
                    isTeePar3: hole.par == 3,
                    stored:    stat.teeShot,
                    category:  teeShotCategory,
                    onCategory: { handleCategory($0, isTee: true) },
                    onDirection: { holeStats[currentHoleIndex].teeShot = $0 }
                )

                // Tee club
                divLine.padding(.vertical, Theme.Spacing.sm + 2)
                ClubPickerButton(
                    label: "Tee Club",
                    selected: Binding(
                        get: { stat.teeClub },
                        set: { holeStats[currentHoleIndex].teeClub = $0 }
                    )
                )

                // ── Approach (conditional) ────────────────────────────────
                if showApproach {
                    VStack(alignment: .leading, spacing: 0) {
                        divLine.padding(.vertical, Theme.Spacing.sm + 2)
                        sectionLabel(icon: "arrow.down.right.circle.fill", title: "Approach")
                            .padding(.bottom, Theme.Spacing.xs + 2)

                        shotPicker(
                            isTeePar3: true,
                            stored:    stat.approach,
                            category:  approachCategory,
                            onCategory: { handleCategory($0, isTee: false) },
                            onDirection: { holeStats[currentHoleIndex].approach = $0 }
                        )

                        // Approach club
                        divLine.padding(.vertical, Theme.Spacing.sm + 2)
                        ClubPickerButton(
                            label: "Approach Club",
                            selected: Binding(
                                get: { stat.approachClub },
                                set: { holeStats[currentHoleIndex].approachClub = $0 }
                            )
                        )
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // Category tap handler
    private func handleCategory(_ cat: ShotCategory, isTee: Bool) {
        withAnimation(Theme.Animation.snappy) {
            if isTee {
                if teeShotCategory == cat {
                    teeShotCategory = nil
                    holeStats[currentHoleIndex].teeShot = nil
                } else {
                    teeShotCategory = cat
                    holeStats[currentHoleIndex].teeShot = cat == .hit
                        ? (hole.par == 3 ? "Green" : "Fairway")
                        : nil
                }
            } else {
                if approachCategory == cat {
                    approachCategory = nil
                    holeStats[currentHoleIndex].approach = nil
                } else {
                    approachCategory = cat
                    holeStats[currentHoleIndex].approach = cat == .hit ? "Green" : nil
                }
            }
        }
    }

    // Shot picker: 4 category tiles + direction strip
    private func shotPicker(
        isTeePar3: Bool,
        stored: String?,
        category: ShotCategory?,
        onCategory: @escaping (ShotCategory) -> Void,
        onDirection: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // 4 category tiles
            HStack(spacing: 6) {
                catTile(.hit,     label: isTeePar3 ? "Green" : "Fairway",
                        icon: "checkmark.circle.fill",   selected: category == .hit,     onTap: onCategory)
                catTile(.missed,  label: "Missed",
                        icon: "arrow.left.and.right",    selected: category == .missed,  onTap: onCategory)
                catTile(.bunker,  label: "Bunker",
                        icon: "oval.fill",               selected: category == .bunker,  onTap: onCategory)
                catTile(.trouble, label: "Trouble",
                        icon: "exclamationmark.triangle.fill", selected: category == .trouble, onTap: onCategory)
            }

            // Direction strip (slides in with spring)
            if let cat = category, cat != .hit {
                if cat == .trouble {
                    dirStrip(label: "Water",
                             items: [("L","Left water"),("R","Right water"),("S","Short water"),("Lg","Long Water")],
                             stored: stored,
                             color: Theme.Colors.water,
                             onTap: onDirection)
                    dirStrip(label: "OB",
                             items: [("L","Out Left"),("R","Out Right"),("S","Out Short"),("Lg","Out Long")],
                             stored: stored,
                             color: Theme.Colors.error,
                             onTap: onDirection)
                } else {
                    let items: [(String, String)] = cat == .missed
                        ? [("Left","Left"),("Right","Right"),("Short","Short"),("Long","Long")]
                        : [("Left","Bunker Left"),("Right","Bunker Right"),("Short","Bunker Short"),("Long","Bunker Long")]
                    dirStrip(label: "", items: items, stored: stored, color: cat.color, onTap: onDirection)
                }
            }
        }
    }

    private func catTile(_ cat: ShotCategory, label: String, icon: String,
                          selected: Bool, onTap: @escaping (ShotCategory) -> Void) -> some View {
        Button(action: { onTap(cat) }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(Theme.Typography.title3)
                    .foregroundStyle(selected ? cat.color : Theme.Colors.textTertiary)
                Text(label)
                    .font(Theme.Typography.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(selected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(selected ? cat.color.opacity(0.10) : Theme.Colors.textPrimary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(selected ? cat.color.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(selected ? 1.0 : 0.96)
        }
        .buttonStyle(ScorlyPressStyle())
        .animation(Theme.Animation.snappy, value: selected)
    }

    private func dirStrip(label: String, items: [(String, String)],
                           stored: String?, color: Color,
                           onTap: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color.opacity(0.65))
                    .frame(width: 42, alignment: .leading)
            }
            ForEach(items, id: \.1) { display, value in
                let sel = stored == value
                Button(action: { onTap(value) }) {
                    Text(display)
                        .font(Theme.Typography.captionSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(sel ? .white : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(sel ? color : Theme.Colors.textPrimary.opacity(0.05))
                        )
                }
                .buttonStyle(ScorlyPressStyle())
                .animation(Theme.Animation.snappy, value: sel)
            }
        }
    }

    // MARK: - Extras card

    private var extrasCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 0) {
                // Auto-computed indicators
                HStack(spacing: Theme.Spacing.xs) {
                    autoChip("GIR",    active: stat.greenInReg(par: hole.par), icon: "flag.fill")
                    autoChip("FIR",    active: stat.fairwayInReg(par: hole.par), icon: "arrow.up.right")
                    autoChip("3-Putt", active: stat.threePutt, icon: "arrow.right.to.line")
                    Spacer()
                }

                // Contextual manual extras
                let needsUpDown   = showApproach && stat.approach != "Green"
                let needsSandSave = stat.approach?.hasPrefix("Bunker") ?? false
                let hasHazard     = stat.outOfBoundsCount > 0 || stat.hazardCount > 0

                if needsUpDown || needsSandSave || hasHazard {
                    divLine.padding(.vertical, Theme.Spacing.xs + 2)
                    HStack(spacing: Theme.Spacing.xs) {
                        if needsUpDown {
                            toggleChip("Up & Down", icon: "arrow.up.arrow.down",
                                       active: stat.upAndDownSuccess) {
                                holeStats[currentHoleIndex].upAndDownSuccess.toggle()
                            }
                        }
                        if needsSandSave {
                            toggleChip("Sand Save", icon: "oval.fill",
                                       active: stat.sandSaveSuccess) {
                                holeStats[currentHoleIndex].sandSaveSuccess.toggle()
                            }
                        }
                        if hasHazard { penaltyRow }
                        Spacer()
                    }
                }
            }
        }
    }

    private func autoChip(_ label: String, active: Bool, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(Theme.Typography.captionSmall)
            Text(label)
                .font(Theme.Typography.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(active ? Theme.Colors.success : Theme.Colors.textTertiary)
        .padding(.horizontal, Theme.Spacing.xs + 2)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? Theme.Colors.success.opacity(0.10) : Theme.Colors.textPrimary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(active ? Theme.Colors.success.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(Theme.Animation.snappy, value: active)
    }

    private func toggleChip(_ label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(Theme.Typography.captionSmall)
                Text(label)
                    .font(Theme.Typography.captionSmall)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(active ? .white : Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.05))
            )
        }
        .buttonStyle(ScorlyPressStyle())
        .animation(Theme.Animation.snappy, value: active)
    }

    private var penaltyRow: some View {
        HStack(spacing: 6) {
            if stat.penaltyStrokes > 0 {
                Button(action: {
                    if holeStats[currentHoleIndex].penaltyStrokes > 0 {
                        holeStats[currentHoleIndex].penaltyStrokes -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .font(Theme.Typography.captionSmall)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.Colors.whisperBorder))
                }
                .buttonStyle(ScorlyPressStyle())

                Text("\(stat.penaltyStrokes)")
                    .font(Theme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()
            }

            Button(action: { holeStats[currentHoleIndex].penaltyStrokes += 1 }) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "plus.circle.fill")
                        .font(Theme.Typography.captionSmall)
                    Text("Penalty")
                        .font(Theme.Typography.captionSmall)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.xs + 2)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.Colors.textPrimary.opacity(0.05)))
            }
            .buttonStyle(ScorlyPressStyle())
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            // Prev
            Button(action: {
                withAnimation(Theme.Animation.snappy) {
                    if currentHoleIndex > 0 { currentHoleIndex -= 1 }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(Theme.Typography.caption).fontWeight(.bold)
                    Text("Prev").font(Theme.Typography.bodySemibold)
                }
                .foregroundStyle(currentHoleIndex == 0 ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                            .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
                )
            }
            .buttonStyle(ScorlyPressStyle()).disabled(currentHoleIndex == 0)

            // Hole indicator
            VStack(spacing: 1) {
                Text("\(hole.number)")
                    .font(Theme.Typography.title)
                    .fontWeight(.black)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Theme.Animation.snappy, value: currentHoleIndex)
                Text("of \(holes.count)")
                    .font(Theme.Typography.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(width: 52)

            // Next / Finish
            Button(action: {
                if isLastHole {
                    showSummary = true
                } else {
                    withAnimation(Theme.Animation.snappy) { currentHoleIndex += 1 }
                }
            }) {
                HStack(spacing: 6) {
                    if isLastHole {
                        Image(systemName: "checkmark").font(Theme.Typography.caption).fontWeight(.bold)
                        Text("Finish").font(Theme.Typography.bodySemibold)
                    } else {
                        Text("Next").font(Theme.Typography.bodySemibold)
                        Image(systemName: "chevron.right").font(Theme.Typography.caption).fontWeight(.bold)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accentLight.opacity(0.8)],
                            startPoint: .top, endPoint: .bottom
                        ))
                )
                // pulse removed — static button
            }
            .buttonStyle(ScorlyPressStyle())
        }
        .padding(.horizontal, Theme.Spacing.pageHorizontal)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Helpers

    private var divLine: some View {
        Rectangle().fill(Theme.Colors.divider).frame(height: 1).frame(maxWidth: .infinity)
    }

    private func formCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(.horizontal, Theme.Spacing.cardPadding).padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
            .themeShadow(Theme.Shadow.subtle)
    }

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(title)
                .font(Theme.Typography.bodySemibold)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

// MARK: - Club picker button

struct ClubPickerButton: View {
    let label: String
    @Binding var selected: String
    @State private var showSheet = false

    var body: some View {
        HStack {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "minus.forwardslash.plus")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text(label)
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Spacer()
            Button(action: { showSheet = true }) {
                Text(selected.isEmpty ? "Select" : selected)
                    .font(Theme.Typography.title3)
                    .foregroundStyle(selected.isEmpty ? Theme.Colors.textTertiary : .white)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(selected.isEmpty ? Theme.Colors.whisperBorder : Theme.Colors.accent)
                    )
            }
            .buttonStyle(ScorlyPressStyle())
            .animation(Theme.Animation.snappy, value: selected)
        }
        .sheet(isPresented: $showSheet) {
            ClubKeypad(selected: $selected, onSelect: { showSheet = false })
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Club keypad sheet

private struct ClubKeypad: View {
    @Binding var selected: String
    let onSelect: () -> Void

    // Laid out in rows of 4 for a clean keypad feel
    private static let clubs: [(d: String, v: String)] = [
        ("D",  "Driver"), ("3W", "3W"),  ("5W", "5W"),  ("3H", "3H"),
        ("4H", "4H"),     ("5H", "5H"),  ("4I", "4I"),  ("5I", "5I"),
        ("6I", "6I"),     ("7I", "7I"),  ("8I", "8I"),  ("9I", "9I"),
        ("PW", "PW"),     ("50", "50"),  ("52", "52"),  ("54", "54"),
        ("56", "56"),     ("58", "58"),  ("60", "60"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle + title
            HStack {
                Text("Select Club")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if !selected.isEmpty {
                    Button(action: { selected = ""; onSelect() }) {
                        Text("Clear")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.xl - 2)
            .padding(.top, Theme.Spacing.xl - 2)
            .padding(.bottom, Theme.Spacing.cardPadding)

            // 4-column keypad grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs + 2), count: 4),
                spacing: Theme.Spacing.xs + 2
            ) {
                ForEach(Self.clubs, id: \.v) { club in
                    let isSel = selected == club.v
                    Button(action: {
                        selected = club.v
                        onSelect()
                    }) {
                        Text(club.d)
                            .font(Theme.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(isSel ? .white : Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous)
                                    .fill(isSel ? Theme.Colors.accent : Theme.Colors.whisperBorder)
                            )
                    }
                    .buttonStyle(ScorlyPressStyle())
                    .animation(Theme.Animation.snappy, value: isSel)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl - 2)

            Spacer()
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
    }
}

// MARK: - Scorecard sheet

private struct ScorecardSheet: View {
    let holes: [CourseHole]
    let holeStats: [HoleStat]
    let teeIndex: Int
    let currentHoleIndex: Int
    let onSelectHole: (Int) -> Void

    private func played(_ s: HoleStat) -> Bool { s.teeShot != nil || s.putts > 0 }

    private var totalPar: Int   { holes.reduce(0) { $0 + $1.par } }
    private var totalScore: Int { holeStats.reduce(0) { $0 + $1.strokes } }
    private var totalPlayed: Int { holeStats.filter { played($0) }.count }
    private var totalDelta: Int {
        holeStats.enumerated().reduce(0) { sum, pair in
            sum + pair.element.strokes - holes[pair.offset].par
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxxs) {
                    Text("Scorecard")
                        .font(Theme.Typography.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(totalPlayed) of \(holes.count) holes played")
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                Spacer()
                // Running total badge
                if totalPlayed > 0 {
                    let delta = totalDelta
                    let label = delta == 0 ? "E" : (delta > 0 ? "+\(delta)" : "\(delta)")
                    let bg: Color = delta < 0
                        ? Theme.Colors.warning                                 // under par → yellow
                        : delta == 0 ? Theme.Colors.textPrimary.opacity(0.07)  // even → neutral
                        : delta < playerHandicap
                            ? Theme.Colors.success                             // within handicap → green
                            : Theme.Colors.error                               // over handicap → red
                    VStack(spacing: Theme.Spacing.xxxs) {
                        Text(label)
                            .font(Theme.Typography.title2)
                            .fontWeight(.black)
                            .foregroundStyle(delta == 0 ? Theme.Colors.textPrimary : .white)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(delta)))
                            .animation(Theme.Animation.bouncy, value: delta)
                        Text("TOTAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(delta == 0 ? Theme.Colors.textSecondary : .white.opacity(0.7))
                            .kerning(1)
                    }
                    .frame(width: 58, height: 52)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(bg))
                    .animation(Theme.Animation.smooth, value: bg)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl - 2)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.md)

            // Column headers
            HStack(spacing: 0) {
                Text("HOLE")
                    .frame(width: 44, alignment: .leading)
                Text("PAR")
                    .frame(width: 36, alignment: .center)
                Spacer()
                Text("SCORE")
                    .frame(width: 58, alignment: .center)
                Text("+/-")
                    .frame(width: 48, alignment: .center)
            }
            .font(Theme.Typography.captionSmall)
            .fontWeight(.bold)
            .foregroundStyle(Theme.Colors.textTertiary)
            .kerning(0.8)
            .padding(.horizontal, Theme.Spacing.xl - 2)
            .padding(.bottom, Theme.Spacing.xs)

            Rectangle()
                .fill(Theme.Colors.divider)
                .frame(height: 1)
                .padding(.horizontal, Theme.Spacing.xl - 2)

            // Hole rows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(holes.enumerated()), id: \.offset) { index, h in
                        let stat = holeStats[index]
                        let isPlayed = played(stat)
                        let isCurrent = index == currentHoleIndex
                        let delta = stat.strokes - h.par

                        Button(action: { onSelectHole(index) }) {
                            HStack(spacing: 0) {
                                // Hole number + current indicator
                                HStack(spacing: 5) {
                                    if isCurrent {
                                        Circle()
                                            .fill(Theme.Colors.accent)
                                            .frame(width: 5, height: 5)
                                    }
                                    Text("\(h.number)")
                                        .font(Theme.Typography.bodySemibold)
                                        .fontWeight(isCurrent ? .black : .semibold)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                                .frame(width: 44, alignment: .leading)

                                // Par
                                Text("\(h.par)")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: 36, alignment: .center)

                                Spacer()

                                // Score badge
                                if isPlayed {
                                    scoreBadge(strokes: stat.strokes, delta: delta)
                                        .frame(width: 58, alignment: .center)
                                } else {
                                    Text("\u{2014}")
                                        .font(Theme.Typography.bodyMedium)
                                        .foregroundStyle(Theme.Colors.textTertiary)
                                        .frame(width: 58, alignment: .center)
                                }

                                // Delta
                                if isPlayed {
                                    let lbl = delta == 0 ? "E" : (delta > 0 ? "+\(delta)" : "\(delta)")
                                    Text(lbl)
                                        .font(Theme.Typography.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(deltaColor(delta))
                                        .monospacedDigit()
                                        .frame(width: 48, alignment: .center)
                                } else {
                                    Text("\u{2014}")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.textTertiary.opacity(0.5))
                                        .frame(width: 48, alignment: .center)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.xl - 2)
                            .frame(height: Theme.Spacing.huge)
                            .background(isCurrent ? Theme.Colors.accent.opacity(0.04) : Color.clear)
                        }
                        .buttonStyle(ScorlyPressStyle())

                        if index < holes.count - 1 {
                            Rectangle()
                                .fill(Theme.Colors.divider.opacity(0.6))
                                .frame(height: 1)
                                .padding(.horizontal, Theme.Spacing.xl - 2)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }

            // Totals footer
            Rectangle()
                .fill(Theme.Colors.divider)
                .frame(height: 1)
                .padding(.horizontal, Theme.Spacing.xl - 2)

            HStack(spacing: 0) {
                Text("TOTAL")
                    .font(Theme.Typography.captionSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .kerning(0.5)
                    .frame(width: 44, alignment: .leading)

                Text("\(totalPar)")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 36, alignment: .center)

                Spacer()

                if totalPlayed > 0 {
                    Text("\(totalScore)")
                        .font(Theme.Typography.title3)
                        .fontWeight(.black)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(totalScore)))
                        .animation(Theme.Animation.bouncy, value: totalScore)
                        .frame(width: 58, alignment: .center)

                    let lbl = totalDelta == 0 ? "E" : (totalDelta > 0 ? "+\(totalDelta)" : "\(totalDelta)")
                    Text(lbl)
                        .font(Theme.Typography.bodyMedium)
                        .fontWeight(.bold)
                        .foregroundStyle(deltaColor(totalDelta))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(totalDelta)))
                        .animation(Theme.Animation.bouncy, value: totalDelta)
                        .frame(width: 48, alignment: .center)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl - 2)
            .frame(height: 52)
        }
        .background(Theme.Colors.canvas.ignoresSafeArea())
    }

    private func scoreBadge(strokes: Int, delta: Int) -> some View {
        let (bg, fg) = scoreBadgeColors(delta: delta)
        return Text("\(strokes)")
            .font(Theme.Typography.bodyMedium)
            .fontWeight(.bold)
            .foregroundStyle(fg)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(bg))
            .monospacedDigit()
    }

    private func scoreBadgeColors(delta: Int) -> (Color, Color) {
        switch delta {
        case ..<(-1): return (Theme.Colors.success, .white)                               // eagle+
        case -1:      return (Theme.Colors.success.opacity(0.15), Theme.Colors.success)   // birdie
        case 0:       return (Theme.Colors.textPrimary.opacity(0.06), Theme.Colors.textPrimary) // par
        case 1:       return (Theme.Colors.warning.opacity(0.18), Theme.Colors.warning)   // bogey
        default:      return (Theme.Colors.error.opacity(0.14), Theme.Colors.error)       // double+
        }
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta < 0 { return Theme.Colors.warning }                                  // under par → amber
        if delta == 0 { return Theme.Colors.textTertiary }                            // even → neutral
        if delta < playerHandicap { return Theme.Colors.success }                     // within handicap → green
        return Theme.Colors.error                                                     // over handicap → red
    }
}
