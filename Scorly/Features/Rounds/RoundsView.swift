//
// RoundsView.swift
// Round history — score trend chart + scrollable round list.
//

import SwiftUI
import Charts

struct RoundsView: View {

    enum Filter: String, CaseIterable {
        case recent20 = "20"
        case all      = "All"
    }

    enum ScoreSegment: String, CaseIterable {
        case full18 = "18"
        case front9 = "F"
        case back9  = "B"
    }

    struct ChartFilter: Equatable {
        var count: Filter = .recent20
        var segment: ScoreSegment = .full18
        var roundTypes: Set<String> = []
        var formats: Set<String> = []
        var tees: Set<String> = []
        var transport: Set<String> = []
        var conditions: Set<String> = []

        var activeCount: Int {
            [count != .recent20,
             segment != .full18,
             !roundTypes.isEmpty,
             !formats.isEmpty,
             !tees.isEmpty,
             !transport.isEmpty,
             !conditions.isEmpty].filter { $0 }.count
        }
    }

    @State private var chartFilter   = ChartFilter()
    @State private var showFilter    = false
    @State private var selectedRound: CompletedRound? = nil
    @State private var rounds: [CompletedRound] = []
    @State private var playerHandicap: Int = 0
    @State private var selectedChartRoundID: UUID? = nil

    // MARK: – Derived data

    private var allRounds: [CompletedRound] {
        rounds.sorted { $0.date < $1.date }
    }

    private var chartRounds: [CompletedRound] {
        var r: [CompletedRound]
        switch chartFilter.count {
        case .recent20: r = Array(allRounds.suffix(20))
        case .all:      r = allRounds
        }
        if chartFilter.segment == .back9 { r = r.filter { $0.hasBackNine } }
        if !chartFilter.roundTypes.isEmpty { r = r.filter { chartFilter.roundTypes.contains($0.roundType) } }
        if !chartFilter.formats.isEmpty    { r = r.filter { chartFilter.formats.contains($0.format) } }
        if !chartFilter.tees.isEmpty       { r = r.filter { chartFilter.tees.contains($0.tee) } }
        if !chartFilter.transport.isEmpty  { r = r.filter { chartFilter.transport.contains($0.transport) } }
        if !chartFilter.conditions.isEmpty { r = r.filter { chartFilter.conditions.contains($0.conditions) } }
        return r
    }

    private var showingAll: Bool { chartFilter.count == .all }

    private func scoreForRound(_ round: CompletedRound) -> Int {
        switch chartFilter.segment {
        case .full18: return round.totalScore
        case .front9: return round.frontNineScore
        case .back9:  return round.backNineScore
        }
    }

    private func parForRound(_ round: CompletedRound) -> Int {
        switch chartFilter.segment {
        case .full18: return round.par
        case .front9: return round.frontNinePar
        case .back9:  return round.backNinePar
        }
    }

    private var chartScores: [Int] { chartRounds.map { scoreForRound($0) } }

    private var chartParValue: Int {
        chartRounds.first.map { parForRound($0) } ?? (chartFilter.segment == .full18 ? 72 : 36)
    }

    private var computedHandicapIndex: Double {
        CompletedRound.handicapIndex(from: Array(allRounds.suffix(20))) ?? Double(playerHandicap)
    }

    private var chartHandicapValue: Int {
        let idx = computedHandicapIndex
        let adj = chartFilter.segment == .full18 ? Int(idx.rounded()) : Int((idx / 2).rounded())
        return chartParValue + adj
    }

    private var chartMinY: Int {
        (chartScores.min().map { min($0, chartHandicapValue) } ?? (chartFilter.segment == .full18 ? 70 : 33)) - 4
    }

    private var chartMaxY: Int {
        (chartScores.max().map { max($0, chartHandicapValue) } ?? (chartFilter.segment == .full18 ? 90 : 48)) + 8
    }

    private var selectedChartRound: CompletedRound? {
        chartRounds.first { $0.id == selectedChartRoundID }
    }

    private var indexedChartRounds: [(index: Int, round: CompletedRound)] {
        chartRounds.enumerated().map { (index: $0.offset, round: $0.element) }
    }

    private var selectedChartIndex: Int? {
        indexedChartRounds.first { $0.round.id == selectedChartRoundID }?.index
    }

    // Available filter options derived from loaded rounds
    private var availableTees: [String]       { Array(Set(allRounds.map(\.tee).filter { !$0.isEmpty })).sorted() }
    private var availableTypes: [String]      { ["Casual", "Tournament", "Practice"] }
    private var availableFormats: [String]    { ["Stroke", "Match", "Scramble", "Other"] }
    private var availableTransport: [String]  { ["Walking", "Riding", "Push Cart", "Mixed"] }
    private var availableConditions: [String] { ["Sunny", "Cloudy", "Windy", "Rainy"] }

    // MARK: – Body

    var body: some View {
        ZStack {
            Theme.Colors.canvas.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rounds")
                        .font(Theme.Typography.largeTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .tabReveal(tab: 2, order: 0)
                        .padding(.bottom, Theme.Spacing.lg)

                    chartCard
                        .tabReveal(tab: 2, order: 1)
                        .padding(.bottom, Theme.Spacing.lg)

                    VStack(spacing: 0) {
                        ForEach(Array(allRounds.reversed().enumerated()), id: \.element.id) { idx, round in
                            if idx > 0 {
                                Divider().padding(.horizontal, Theme.Spacing.md)
                            }
                            roundRow(round)
                                .onTapGesture { selectedRound = round }
                        }
                    }
                    .background(Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
                    .themeShadow(Theme.Shadow.subtle)
                    .tabReveal(tab: 2, order: 2)
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await loadRounds() }
        .sheet(item: $selectedRound) { round in
            RoundDetailView(round: round, onDelete: {
                selectedRound = nil
                Task { await loadRounds() }
            })
        }
        .sheet(isPresented: $showFilter) {
            ChartFilterSheet(
                filter: $chartFilter,
                availableTees: availableTees,
                availableTypes: availableTypes,
                availableFormats: availableFormats,
                availableTransport: availableTransport,
                availableConditions: availableConditions
            )
        }
    }

    private func loadRounds() async {
        do {
            let courseRows = try await DataService.shared.fetchCourses()
            let roundRows  = try await DataService.shared.fetchRounds()
            let courseMap  = Dictionary(uniqueKeysWithValues: courseRows.map { ($0.courseId, $0) })
            rounds = roundRows.compactMap { row in
                guard let course = courseMap[row.courseId] else { return nil }
                return CompletedRound(from: row, course: course)
            }
            if let profile = try await DataService.shared.fetchUserProfile() {
                playerHandicap = Int(profile.handicapIndex ?? 0)
                UserDefaults.standard.set(playerHandicap, forKey: "cachedPlayerHandicap")
            }
        } catch {
            rounds = []
        }
    }

    // MARK: – Chart card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: title + filter button
            HStack(alignment: .center) {
                Text("Score Trend")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button { showFilter = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(Theme.Typography.title3)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .fill(Theme.Colors.whisperBorder)
                            )
                        if chartFilter.activeCount > 0 {
                            Circle()
                                .fill(Theme.Colors.textPrimary)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(ScorlyPressStyle())
            }
            .padding(.bottom, Theme.Spacing.md)

            if chartRounds.isEmpty {
                Text("No rounds match the current filters.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 160)
            } else {
                roundsChart

                HStack(spacing: 14) {
                    Spacer()
                    legendItem(label: "Par", opacity: 0.18, dash: [4, 3])
                    legendItem(label: "HCP \(String(format: "%.1f", computedHandicapIndex))", opacity: 0.42, dash: [5, 4])
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    // MARK: – Chart

    private var roundsChart: some View {
        Chart {
            RuleMark(y: .value("Par", chartParValue))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            RuleMark(y: .value("HCP", chartHandicapValue))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.42))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

            ForEach(indexedChartRounds, id: \.round.id) { item in
                AreaMark(
                    x: .value("Index", item.index),
                    yStart: .value("Base", chartMinY),
                    yEnd: .value("Score", scoreForRound(item.round))
                )
                .foregroundStyle(LinearGradient(
                    colors: [Theme.Colors.textPrimary.opacity(0.08), Theme.Colors.textPrimary.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.monotone)
            }

            ForEach(indexedChartRounds, id: \.round.id) { item in
                LineMark(
                    x: .value("Index", item.index),
                    y: .value("Score", scoreForRound(item.round))
                )
                .foregroundStyle(Theme.Colors.textPrimary)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: showingAll ? 2 : 2.5))

                if !showingAll {
                    PointMark(
                        x: .value("Index", item.index),
                        y: .value("Score", scoreForRound(item.round))
                    )
                    .foregroundStyle(roundPointColor(for: item.round))
                    .symbolSize(52)
                }
            }

            if !showingAll, let selectedChartIndex, let selectedChartRound {
                PointMark(
                    x: .value("Selected Index", selectedChartIndex),
                    y: .value("Selected Score", scoreForRound(selectedChartRound))
                )
                .foregroundStyle(.clear)
                .symbolSize(1)
                .annotation(position: .top, spacing: 8) {
                    roundScoreCallout(
                        value: scoreForRound(selectedChartRound),
                        color: roundPointColor(for: selectedChartRound)
                    )
                }
            }
        }
        .chartYScale(domain: chartMinY...chartMaxY)
        .chartXScale(domain: -0.5...(Double(max(chartRounds.count - 1, 0)) + 0.5))
        .chartXAxis {
            if showingAll {
                AxisMarks { _ in }
            } else {
                let stride = chartRounds.count > 12 ? 4 : chartRounds.count > 6 ? 2 : 1
                AxisMarks(values: Array(Swift.stride(from: 0, to: chartRounds.count, by: stride))) { value in
                    AxisValueLabel {
                        if let idx = value.as(Int.self), idx < chartRounds.count {
                            let date = chartRounds[idx].date
                            VStack(spacing: 1) {
                                Text(date, format: .dateTime.month(.abbreviated))
                                Text(date, format: .dateTime.day())
                            }
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(Theme.Colors.textTertiary)
                        }
                    }
                    AxisTick()
                    AxisGridLine().foregroundStyle(Theme.Colors.whisperBorder)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisValueLabel()
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textTertiary)
                AxisGridLine().foregroundStyle(Theme.Colors.whisperBorder)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        guard !showingAll else { return }
                        let location = value.location
                        guard let plotFrameAnchor = proxy.plotFrame else { selectedChartRoundID = nil; return }
                        let plotFrame = geometry[plotFrameAnchor]
                        let plotLocation = CGPoint(x: location.x - plotFrame.origin.x, y: location.y - plotFrame.origin.y)
                        guard plotFrame.contains(location) else { selectedChartRoundID = nil; return }
                        let nearest = indexedChartRounds.compactMap { item -> (round: CompletedRound, distance: CGFloat)? in
                            guard let x = proxy.position(forX: item.index),
                                  let y = proxy.position(forY: scoreForRound(item.round))
                            else { return nil }
                            let dx = x - plotLocation.x
                            let dy = y - plotLocation.y
                            return (item.round, sqrt(dx*dx + dy*dy))
                        }.min { $0.distance < $1.distance }
                        selectedChartRoundID = nearest?.distance ?? 999 <= 28 ? nearest?.round.id : nil
                    })
            }
        }
        .frame(height: 200)
    }

    // MARK: – Helpers

    private func roundPointColor(for round: CompletedRound) -> Color {
        let score = scoreForRound(round)
        let par   = parForRound(round)
        let idx   = computedHandicapIndex
        let adj   = chartFilter.segment == .full18 ? Int(idx.rounded()) : Int((idx / 2).rounded())
        return score <= par + adj
            ? Theme.Colors.success
            : Theme.Colors.error
    }

    private func roundScoreCallout(value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(Theme.Typography.captionSmall)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.Colors.surface.opacity(0.98)).shadow(color: Theme.Colors.textPrimary.opacity(0.10), radius: 4, y: 2))
            .overlay(Capsule().strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
    }

    private func legendItem(label: String, opacity: Double, dash: [CGFloat]) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(Theme.Colors.textPrimary.opacity(opacity))
                .frame(width: 16, height: 1.5)
                .overlay(GeometryReader { geo in
                    Path { path in
                        var x: CGFloat = 0
                        while x < geo.size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: min(x + dash[0], geo.size.width), y: 0))
                            x += dash[0] + (dash.count > 1 ? dash[1] : 0)
                        }
                    }
                    .stroke(Theme.Colors.textPrimary.opacity(opacity), lineWidth: 1.5)
                })
            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: – Round row

    private func roundRow(_ round: CompletedRound) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(round.scoreVsParText)
                    .font(Theme.Typography.title2)
                    .foregroundStyle(round.scoreColor)
                    .monospacedDigit()
                Text("\(round.totalScore)")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
            }
            .frame(width: 46)

            Rectangle().fill(Theme.Colors.whisperBorder).frame(width: 1, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(round.courseName)
                    .font(Theme.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 6) {
                    Text(round.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if !round.conditions.isEmpty {
                        Text("\u{00B7}")
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(Theme.Colors.textTertiary)
                        Text(round.conditions)
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if let notes = round.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "note.text")
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(Theme.Typography.captionSmall)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
    }
}

// MARK: – Chart Filter Sheet

private struct ChartFilterSheet: View {
    @Binding var filter: RoundsView.ChartFilter
    let availableTees: [String]
    let availableTypes: [String]
    let availableFormats: [String]
    let availableTransport: [String]
    let availableConditions: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                    filterSection(title: "Rounds") {
                        singleSelectRow(
                            options: [(RoundsView.Filter.recent20, "Last 20"), (.all, "All")],
                            selected: filter.count,
                            onSelect: { filter.count = $0 }
                        )
                    }

                    filterSection(title: "Holes") {
                        singleSelectRow(
                            options: [(RoundsView.ScoreSegment.full18, "18 Holes"), (.front9, "Front 9"), (.back9, "Back 9")],
                            selected: filter.segment,
                            onSelect: { filter.segment = $0 }
                        )
                    }

                    filterSection(title: "Round Type") {
                        pillGrid(options: availableTypes, selected: $filter.roundTypes)
                    }

                    filterSection(title: "Format") {
                        pillGrid(options: availableFormats, selected: $filter.formats)
                    }

                    if !availableTees.isEmpty {
                        filterSection(title: "Tees") {
                            pillGrid(options: availableTees, selected: $filter.tees)
                        }
                    }

                    filterSection(title: "Transport") {
                        pillGrid(options: availableTransport, selected: $filter.transport)
                    }

                    filterSection(title: "Conditions") {
                        pillGrid(options: availableConditions, selected: $filter.conditions)
                    }
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .navigationTitle("Chart Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        withAnimation(Theme.Animation.snappy) {
                            filter = RoundsView.ChartFilter()
                        }
                    }
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.bodySemibold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            .background(Theme.Colors.canvas.ignoresSafeArea())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.Spacing.lg)
        .interactiveDismissDisabled(false)
    }

    // MARK: Section wrapper

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(Theme.Typography.captionSmall)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(0.8)
            content()
        }
    }

    // MARK: Single-select row (for Count + Holes)

    private func singleSelectRow<T: Equatable>(
        options: [(T, String)],
        selected: T,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, pair in
                let isSelected = pair.0 == selected
                Button { withAnimation(Theme.Animation.snappy) { onSelect(pair.0) } } label: {
                    Text(pair.1)
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Theme.Colors.textPrimary : Theme.Colors.whisperBorder)
                        )
                }
                .buttonStyle(ScorlyPressStyle())
                .animation(Theme.Animation.snappy, value: selected)
            }
        }
    }

    // MARK: Multi-select pill grid

    private func pillGrid(options: [String], selected: Binding<Set<String>>) -> some View {
        let cols = [GridItem(.adaptive(minimum: 90), spacing: Theme.Spacing.xs)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.wrappedValue.contains(option)
                Button {
                    withAnimation(Theme.Animation.snappy) {
                        if isOn { selected.wrappedValue.remove(option) }
                        else    { selected.wrappedValue.insert(option) }
                    }
                } label: {
                    Text(option)
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isOn ? .white : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isOn ? Theme.Colors.textPrimary : Theme.Colors.whisperBorder)
                        )
                }
                .buttonStyle(ScorlyPressStyle())
                .animation(Theme.Animation.snappy, value: isOn)
            }
        }
    }
}
