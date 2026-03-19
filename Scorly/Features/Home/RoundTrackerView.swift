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
    private let cr: CGFloat = 13

    // MARK: Supporting types

    enum ShotCategory: Equatable {
        case hit, missed, bunker, trouble
        var color: Color {
            switch self {
            case .hit:     return Color(red: 0.486, green: 0.718, blue: 0.498)
            case .missed:  return Color(red: 0.94, green: 0.67, blue: 0.16)
            case .bunker:  return Color(red: 0.82, green: 0.65, blue: 0.38)
            case .trouble: return Color(red: 0.88, green: 0.28, blue: 0.24)
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

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        holeInfoCard
                        scoreCard
                        shotFlowCard
                        if showExtras { extrasCard }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 108)
                }
                .scrollBounceBehavior(.basedOnSize)
                .contentMargins(.top, 0, for: .scrollContent)
            }

            if showDeleteConfirm {
                DeleteRoundPopup(
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.18)) { showDeleteConfirm = false }
                        roundStore.deleteRoundAndExit()
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.18)) { showDeleteConfirm = false }
                    }
                )
                .zIndex(99)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: showDeleteConfirm)
            }

            bottomNav
                .background(
                    Color(red: 0.97, green: 0.97, blue: 0.98)
                        .shadow(color: .black.opacity(0.07), radius: 16, y: -4)
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
                    withAnimation(.easeInOut(duration: 0.18)) { currentHoleIndex = index }
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(.white, in: Circle())
                    .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(course.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Text("Hole \(hole.number) of \(holes.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.4))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showScorecard = true }) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(.white, in: Circle())
                        .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.24))
                        .frame(width: 42, height: 42)
                        .background(.white, in: Circle())
                        .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
    }

    // MARK: - Hole info card

    private var holeInfoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(Color.black)

            VStack(alignment: .leading, spacing: 0) {
                // Top row: hole number + score badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("HOLE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(1.4)
                        Text("\(hole.number)")
                            .font(.system(size: 64, weight: .black))
                            .foregroundStyle(.white)
                            .lineSpacing(0)
                            .padding(.top, -4)
                    }

                    Spacer()

                    // Always show running score badge
                    let score = runningScore
                    let scoreLabel = score == 0 ? "E" : (score > 0 ? "+\(score)" : "\(score)")
                    let scoreBg: Color = score < 0
                        ? Color(red: 0.94, green: 0.78, blue: 0.10)          // under par → yellow
                        : score == 0 ? Color.white.opacity(0.15)              // even → neutral
                        : score < playerHandicap
                            ? Color(red: 0.486, green: 0.718, blue: 0.498)      // within handicap → green
                            : Color(red: 0.88, green: 0.28, blue: 0.24)      // over handicap → red
                    VStack(spacing: 3) {
                        Text(scoreLabel)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.15), value: score)
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .kerning(1.2)
                    }
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(scoreBg))
                    .animation(.easeInOut(duration: 0.15), value: scoreBg)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Stat pills row
                HStack(spacing: 8) {
                    holeStatPill(value: "Par \(hole.par)", icon: "flag.fill")
                    if let yds = hole.yardages[safe: teeIndex] {
                        holeStatPill(value: "\(yds) yds", icon: "arrow.up.forward")
                    }
                    holeStatPill(value: "Hcp \(hole.handicap)", icon: "bolt.fill")
                    holeStatPill(value: "\(stat.strokes)", icon: "figure.golf")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private func holeStatPill(value: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(stat.strokes <= 1 ? .black.opacity(0.2) : .black)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(stat.strokes <= 1)

                        Text("\(stat.strokes)")
                            .font(.system(size: 58, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.12), value: stat.strokes)

                        Button(action: { holeStats[currentHoleIndex].strokes += 1 }) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Score-to-par label for this hole
                    let holeDelta = stat.strokes - hole.par
                    let deltaLabel = holeDelta == 0 ? "Even" : (holeDelta > 0 ? "+\(holeDelta)" : "\(holeDelta)")
                    // Handicap strokes: player gets a stroke on holes where hole handicap <= player handicap
                    let hcpStrokes = hole.handicap <= playerHandicap ? 1 : 0
                    let adjustedDelta = holeDelta - hcpStrokes
                    let deltaColor: Color = holeDelta < 0
                        ? Color(red: 0.72, green: 0.52, blue: 0.00)           // under par → amber
                        : adjustedDelta <= 0 ? Color(red: 0.12, green: 0.55, blue: 0.30) // within handicap → green
                        : holeDelta == 0 ? .black.opacity(0.35)               // even, no stroke → neutral
                        : Color(red: 0.75, green: 0.18, blue: 0.15)           // over handicap → red
                    Text(deltaLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(deltaColor)
                        .monospacedDigit()
                        .animation(.easeInOut(duration: 0.12), value: holeDelta)
                }
                .padding(.bottom, 16)

                // ── Divider ───────────────────────────────────────────────
                divLine

                // ── Putts — dot picker ────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel(icon: "arrow.right.to.line", title: "Putts")
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { n in
                            Button(action: {
                                holeStats[currentHoleIndex].putts = stat.putts == n ? 0 : n
                            }) {
                                Circle()
                                    .fill(n <= stat.putts ? Color.black : Color.black.opacity(0.09))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text("\(n)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(n <= stat.putts ? .white : .black.opacity(0.3))
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.12), value: stat.putts)
                        }
                        Spacer()
                        if stat.putts > 0 {
                            Text("\(stat.putts) putt\(stat.putts == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.black.opacity(0.35))
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Shot flow card

    private var shotFlowCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 0) {
                // ── Tee shot ──────────────────────────────────────────────
                sectionLabel(icon: "arrow.up.right.circle.fill", title: "Tee Shot")
                    .padding(.bottom, 10)

                shotPicker(
                    isTeePar3: hole.par == 3,
                    stored:    stat.teeShot,
                    category:  teeShotCategory,
                    onCategory: { handleCategory($0, isTee: true) },
                    onDirection: { holeStats[currentHoleIndex].teeShot = $0 }
                )

                // Tee club
                divLine.padding(.vertical, 14)
                ClubPickerButton(
                    label: "Tee Club",
                    selected: Binding(
                        get: { stat.teeClub },
                        set: { holeStats[currentHoleIndex].teeClub = $0 }
                    )
                )

                // ── Approach (conditional) ────────────────────────────────
                if showApproach {
                    divLine.padding(.vertical, 14)
                    sectionLabel(icon: "arrow.down.right.circle.fill", title: "Approach")
                        .padding(.bottom, 10)

                    shotPicker(
                        isTeePar3: true,
                        stored:    stat.approach,
                        category:  approachCategory,
                        onCategory: { handleCategory($0, isTee: false) },
                        onDirection: { holeStats[currentHoleIndex].approach = $0 }
                    )

                    // Approach club
                    divLine.padding(.vertical, 14)
                    ClubPickerButton(
                        label: "Approach Club",
                        selected: Binding(
                            get: { stat.approachClub },
                            set: { holeStats[currentHoleIndex].approachClub = $0 }
                        )
                    )
                }
            }
        }
    }

    // Category tap handler
    private func handleCategory(_ cat: ShotCategory, isTee: Bool) {
        withAnimation(.easeInOut(duration: 0.18)) {
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
        VStack(alignment: .leading, spacing: 8) {
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

            // Direction strip (slides in)
            if let cat = category, cat != .hit {
                if cat == .trouble {
                    dirStrip(label: "Water",
                             items: [("L","Left water"),("R","Right water"),("S","Short water"),("Lg","Long Water")],
                             stored: stored,
                             color: Color(red: 0.33, green: 0.55, blue: 0.90),
                             onTap: onDirection)
                    dirStrip(label: "OB",
                             items: [("L","Out Left"),("R","Out Right"),("S","Out Short"),("Lg","Out Long")],
                             stored: stored,
                             color: Color(red: 0.88, green: 0.28, blue: 0.24),
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? cat.color : .black.opacity(0.3))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? .black : .black.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? cat.color.opacity(0.10) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? cat.color.opacity(0.45) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.14), value: selected)
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(sel ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(sel ? color : Color.black.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.12), value: sel)
            }
        }
    }

    // MARK: - Extras card

    private var extrasCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 0) {
                // Auto-computed indicators
                HStack(spacing: 8) {
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
                    divLine.padding(.vertical, 10)
                    HStack(spacing: 8) {
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
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(active ? Color(red: 0.486, green: 0.718, blue: 0.498) : Color.black.opacity(0.28))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.10) : Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(active ? Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.14), value: active)
    }

    private func toggleChip(_ label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(active ? .white : .black)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? Color.black : Color.black.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: active)
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
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Text("\(stat.penaltyStrokes)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .monospacedDigit()
            }

            Button(action: { holeStats[currentHoleIndex].penaltyStrokes += 1 }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Penalty")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom nav

    private var bottomNav: some View {
        HStack(spacing: 10) {
            // Prev
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if currentHoleIndex > 0 { currentHoleIndex -= 1 }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .bold))
                    Text("Prev").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(currentHoleIndex == 0 ? Color.black.opacity(0.2) : .black)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous)
                            .strokeBorder(.black.opacity(0.08), lineWidth: 1))
                )
            }
            .buttonStyle(.plain).disabled(currentHoleIndex == 0)

            // Hole indicator
            VStack(spacing: 1) {
                Text("\(hole.number)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.black)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.18), value: currentHoleIndex)
                Text("of \(holes.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
            }
            .frame(width: 52)

            // Next / Finish
            Button(action: {
                if isLastHole {
                    showSummary = true
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { currentHoleIndex += 1 }
                }
            }) {
                HStack(spacing: 6) {
                    if isLastHole {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        Text("Finish").font(.system(size: 15, weight: .semibold))
                    } else {
                        Text("Next").font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: cr, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.22, green: 0.22, blue: 0.24), Color.black],
                            startPoint: .top, endPoint: .bottom
                        ))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private var divLine: some View {
        Rectangle().fill(Color.black.opacity(0.06)).frame(height: 1).frame(maxWidth: .infinity)
    }

    private func formCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(.horizontal, 18).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: cr, style: .continuous)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.38))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
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
            HStack(spacing: 8) {
                Image(systemName: "minus.forwardslash.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.38))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
            }
            Spacer()
            Button(action: { showSheet = true }) {
                Text(selected.isEmpty ? "Select" : selected)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected.isEmpty ? .black.opacity(0.3) : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected.isEmpty ? Color.black.opacity(0.06) : Color.black)
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.14), value: selected)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                if !selected.isEmpty {
                    Button(action: { selected = ""; onSelect() }) {
                        Text("Clear")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)

            // 4-column keypad grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(Self.clubs, id: \.v) { club in
                    let isSel = selected == club.v
                    Button(action: {
                        selected = club.v
                        onSelect()
                    }) {
                        Text(club.d)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSel ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSel ? Color.black : Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.10), value: isSel)
                }
            }
            .padding(.horizontal, 22)

            Spacer()
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scorecard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                    Text("\(totalPlayed) of \(holes.count) holes played")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.38))
                }
                Spacer()
                // Running total badge
                if totalPlayed > 0 {
                    let delta = totalDelta
                    let label = delta == 0 ? "E" : (delta > 0 ? "+\(delta)" : "\(delta)")
                    let bg: Color = delta < 0
                        ? Color(red: 0.94, green: 0.78, blue: 0.10)           // under par → yellow
                        : delta == 0 ? Color.black.opacity(0.07)              // even → neutral
                        : delta < playerHandicap
                            ? Color(red: 0.486, green: 0.718, blue: 0.498)       // within handicap → green
                            : Color(red: 0.88, green: 0.28, blue: 0.24)       // over handicap → red
                    VStack(spacing: 2) {
                        Text(label)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(delta == 0 ? .black : .white)
                            .monospacedDigit()
                        Text("TOTAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(delta == 0 ? .black.opacity(0.45) : .white.opacity(0.7))
                            .kerning(1)
                    }
                    .frame(width: 58, height: 52)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 16)

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
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.black.opacity(0.32))
            .kerning(0.8)
            .padding(.horizontal, 22)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 22)

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
                                            .fill(Color.black)
                                            .frame(width: 5, height: 5)
                                    }
                                    Text("\(h.number)")
                                        .font(.system(size: 15, weight: isCurrent ? .black : .semibold))
                                        .foregroundStyle(.black)
                                }
                                .frame(width: 44, alignment: .leading)

                                // Par
                                Text("\(h.par)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.45))
                                    .frame(width: 36, alignment: .center)

                                Spacer()

                                // Score badge
                                if isPlayed {
                                    scoreBadge(strokes: stat.strokes, delta: delta)
                                        .frame(width: 58, alignment: .center)
                                } else {
                                    Text("—")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.black.opacity(0.2))
                                        .frame(width: 58, alignment: .center)
                                }

                                // Delta
                                if isPlayed {
                                    let lbl = delta == 0 ? "E" : (delta > 0 ? "+\(delta)" : "\(delta)")
                                    Text(lbl)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(deltaColor(delta))
                                        .monospacedDigit()
                                        .frame(width: 48, alignment: .center)
                                } else {
                                    Text("—")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.black.opacity(0.15))
                                        .frame(width: 48, alignment: .center)
                                }
                            }
                            .padding(.horizontal, 22)
                            .frame(height: 48)
                            .background(isCurrent ? Color.black.opacity(0.03) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        if index < holes.count - 1 {
                            Rectangle()
                                .fill(Color.black.opacity(0.045))
                                .frame(height: 1)
                                .padding(.horizontal, 22)
                        }
                    }
                }
                .padding(.bottom, 24)
            }

            // Totals footer
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 22)

            HStack(spacing: 0) {
                Text("TOTAL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .kerning(0.5)
                    .frame(width: 44, alignment: .leading)

                Text("\(totalPar)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                    .frame(width: 36, alignment: .center)

                Spacer()

                if totalPlayed > 0 {
                    Text("\(totalScore)")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                        .frame(width: 58, alignment: .center)

                    let lbl = totalDelta == 0 ? "E" : (totalDelta > 0 ? "+\(totalDelta)" : "\(totalDelta)")
                    Text(lbl)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(deltaColor(totalDelta))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .center)
                }
            }
            .padding(.horizontal, 22)
            .frame(height: 52)
        }
        .background(Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
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
        case ..<(-1): return (Color(red: 0.10, green: 0.60, blue: 0.30), .white)         // eagle+
        case -1:      return (Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.15), Color(red: 0.416, green: 0.682, blue: 0.427)) // birdie
        case 0:       return (Color.black.opacity(0.06), .black)                          // par
        case 1:       return (Color(red: 0.94, green: 0.67, blue: 0.16).opacity(0.18), Color(red: 0.72, green: 0.48, blue: 0.05)) // bogey
        default:      return (Color(red: 0.88, green: 0.28, blue: 0.24).opacity(0.14), Color(red: 0.75, green: 0.18, blue: 0.15)) // double+
        }
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta < 0 { return Color(red: 0.72, green: 0.52, blue: 0.00) }           // under par → amber
        if delta == 0 { return Color.black.opacity(0.38) }                           // even → neutral
        if delta < playerHandicap { return Color(red: 0.12, green: 0.55, blue: 0.30) } // within handicap → green
        return Color(red: 0.75, green: 0.18, blue: 0.15)                             // over handicap → red
    }
}
