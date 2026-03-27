//
// HomeView.swift
// Landing page — Play Round card or In-Progress card.
// Tapping Play Round animates to the Courses tab (tab 1).
//

import SwiftUI
import Charts

struct HomeView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var roundStore: RoundStore
    @State private var showResume = false
    @State private var showDeleteConfirm = false
    @State private var rounds: [CompletedRound] = []
    @State private var selectedTrendRoundID: UUID? = nil


    // Calendar
    enum CalendarMode { case month, year }
    @State private var calendarMode: CalendarMode = .month
    @State private var displayedMonth: Date = Date()
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private let cr: CGFloat = 13
    private let mainCardTopSpacing: CGFloat = 4

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    mainCard
                        .padding(.horizontal, 20)
                        .padding(.top, mainCardTopSpacing)

                    sparklineCard
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    calendarCard
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
                .padding(.bottom, 80)
            }
            .scrollBounceBehavior(.basedOnSize)

            if showDeleteConfirm {
                DeleteRoundPopup(
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.18)) { showDeleteConfirm = false }
                        roundStore.deleteRound()
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
        .fullScreenCover(isPresented: $showResume) {
            if let round = roundStore.activeRound {
                NavigationStack {
                    RoundTrackerView(resumingFrom: round)
                }
                .environmentObject(roundStore)
            }
        }
        .onChange(of: roundStore.pendingDismissToHome) { _, triggered in
            if triggered { showResume = false }
        }
        .onChange(of: roundStore.pendingDismissToRounds) { _, triggered in
            if triggered { showResume = false }
        }
        .task { await loadRounds() }
    }

    private func loadRounds() async {
        do {
            let courseRows = try await DataService.shared.fetchCourses()
            let roundRows = try await DataService.shared.fetchRounds()
            let courseMap = Dictionary(uniqueKeysWithValues: courseRows.map { ($0.courseId, $0) })
            rounds = roundRows.compactMap { row in
                guard let course = courseMap[row.courseId] else { return nil }
                return CompletedRound(from: row, course: course)
            }
        } catch {
            rounds = []
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
            Text(dateString)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black.opacity(0.38))
        }
        .padding(.bottom, 4)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning." }
        if h < 17 { return "Good afternoon." }
        return "Good evening."
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // MARK: - Main card

    @ViewBuilder
    private var mainCard: some View {
        if let round = roundStore.activeRound {
            inProgressCard(round: round)
        } else {
            playRoundCard
        }
    }

    // MARK: - Play Round card

    private var playRoundCard: some View {
        Button(action: {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                selectedTab = 1
            }
        }) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.32, green: 0.32, blue: 0.34),
                                Color.black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.10), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)

                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.10))
                            .frame(width: 52, height: 52)
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Play Round")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Text("Choose a course")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.50))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 212)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private var barRounds: [CompletedRound] {
        Array(rounds.sorted { $0.date < $1.date }.suffix(10))
    }

    private var barScores: [Int] { barRounds.map(\.totalScore) }

    private var barAvg: Int {
        barScores.isEmpty ? 80 : barScores.reduce(0, +) / barScores.count
    }

    private var barMinY: Int { (barScores.min() ?? 70) - 4 }
    private var barMaxY: Int { (barScores.max() ?? 90) + 5 }

    private var selectedBarRound: CompletedRound? {
        barRounds.first { $0.id == selectedTrendRoundID }
    }

    // MARK: - Sparkline card

    private var sparklineCard: some View {
        let trendDown = barScores.count >= 4 &&
            (barScores.suffix(2).reduce(0, +) / 2) < (barScores.prefix(2).reduce(0, +) / 2)
        let trendLabel  = trendDown ? "Improving" : "Trending up"
        let trendIcon   = trendDown ? "arrow.down.right" : "arrow.up.right"
        let trendColor  = trendDown
            ? Color(red: 0.353, green: 0.620, blue: 0.365)
            : Color(red: 0.70, green: 0.15, blue: 0.15)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Recent Scores")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                if barScores.count >= 2 {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .font(.system(size: 10, weight: .bold))
                        Text(trendLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(trendColor)
                }
            }

            if barRounds.isEmpty {
                Text("No rounds yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.30))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 100)
            } else {
                barChart
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private var indexedBarRounds: [(index: Int, round: CompletedRound)] {
        barRounds.enumerated().map { (index: $0.offset, round: $0.element) }
    }

    private func barColor(for round: CompletedRound) -> Color {
        round.totalScore <= barAvg
            ? Color(red: 0.353, green: 0.620, blue: 0.365)
            : Color(red: 0.70, green: 0.15, blue: 0.15)
    }

    private func barLabel(for index: Int) -> String {
        String(index)
    }

    private var barChart: some View {
        Chart {
            RuleMark(y: .value("Avg", Double(barAvg)))
                .foregroundStyle(.black.opacity(0.14))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))

            ForEach(indexedBarRounds, id: \.round.id) { item in
                BarMark(
                    x: .value("Index", barLabel(for: item.index)),
                    yStart: .value("Base", Double(barMinY)),
                    yEnd: .value("Score", Double(item.round.totalScore)),
                    width: .ratio(0.55)
                )
                .foregroundStyle(barColor(for: item.round))
                .cornerRadius(4)
            }

            if let selectedBarRound,
               let selIdx = indexedBarRounds.first(where: { $0.round.id == selectedBarRound.id })?.index {
                BarMark(
                    x: .value("Index", barLabel(for: selIdx)),
                    yStart: .value("Base", Double(barMinY)),
                    yEnd: .value("Score", Double(selectedBarRound.totalScore)),
                    width: .ratio(0.55)
                )
                .foregroundStyle(.clear)
                .annotation(position: .top, spacing: 6) {
                    barCallout(value: selectedBarRound.totalScore, color: barColor(for: selectedBarRound))
                }
            }
        }
        .chartYScale(domain: Double(barMinY)...Double(barMaxY))
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self), let idx = Int(label), idx < barRounds.count {
                        Text(barRounds[idx].date, format: .dateTime.day())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.35))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisValueLabel()
                    .font(.system(size: 9))
                    .foregroundStyle(Color.black.opacity(0.30))
                AxisGridLine()
                    .foregroundStyle(Color.black.opacity(0.06))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        let location = value.location
                        guard let plotFrameAnchor = proxy.plotFrame else {
                            selectedTrendRoundID = nil; return
                        }
                        let plotFrame = geometry[plotFrameAnchor]
                        guard plotFrame.contains(location) else {
                            selectedTrendRoundID = nil; return
                        }
                        let plotX = location.x - plotFrame.origin.x
                        let nearest = indexedBarRounds.compactMap { item -> (round: CompletedRound, dist: CGFloat)? in
                            guard let x = proxy.position(forX: barLabel(for: item.index)) else { return nil }
                            return (item.round, abs(x - plotX))
                        }.min { $0.dist < $1.dist }
                        if let nearest, nearest.dist <= 24 {
                            selectedTrendRoundID = nearest.round.id
                        } else {
                            selectedTrendRoundID = nil
                        }
                    })
            }
        }
        .frame(height: 130)
    }

    private func barCallout(value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color.opacity(0.90))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
            )
            .overlay(
                Capsule()
                    .strokeBorder(.black.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Calendar card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Activity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                if calendarMode == .year {
                    HStack(spacing: 2) {
                        Button { selectedYear -= 1 } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.black.opacity(0.45))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)

                        Text(String(selectedYear))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .monospacedDigit()
                            .frame(minWidth: 38, alignment: .center)

                        Button {
                            let thisYear = Calendar.current.component(.year, from: Date())
                            if selectedYear < thisYear { selectedYear += 1 }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selectedYear < Calendar.current.component(.year, from: Date()) ? .black.opacity(0.45) : .black.opacity(0.18))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                    }
                }
                recessedToggle(
                    options: [("M", CalendarMode.month), ("Y", CalendarMode.year)],
                    selected: calendarMode
                ) { calendarMode = $0 }
            }

            if calendarMode == .month {
                monthCalendarView
            } else {
                yearCalendarView
            }

            // Legend
            HStack(spacing: 14) {
                Spacer()
                calLegend(color: Color.black.opacity(0.08), label: "No round")
                calLegend(color: Color.black.opacity(0.78), label: "Played")
                calLegend(color: Color(red: 0.353, green: 0.620, blue: 0.365), label: "Good round")
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func recessedToggle<T: Equatable>(
        options: [(String, T)],
        selected: T,
        onChange: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selected == option.1
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        onChange(option.1)
                    }
                } label: {
                    Text(option.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .black : .black.opacity(0.40))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            Group {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(.white)
                                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.black.opacity(0.06))
        )
        .frame(width: CGFloat(options.count) * 30)
    }

    private func calLegend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))
        }
    }

    // MARK: - Month calendar

    private var monthCalendarView: some View {
        let cal = Calendar.current
        let days = monthDays(for: displayedMonth)

        return VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.20)) {
                        displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.45))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString(displayedMonth))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.20)) {
                        if let next = cal.date(byAdding: .month, value: 1, to: displayedMonth),
                           cal.compare(next, to: Date(), toGranularity: .month) != .orderedDescending {
                            displayedMonth = next
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.45))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            // Day-of-week headers
            let headers = ["S","M","T","W","T","F","S"]
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(headers[i])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            VStack(spacing: 4) {
                ForEach(Array(stride(from: 0, to: days.count, by: 7)), id: \.self) { start in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { offset in
                            let idx = start + offset
                            monthDayCell(day: idx < days.count ? days[idx] : nil)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthDayCell(day: Date?) -> some View {
        if let date = day {
            let cal = Calendar.current
            let isToday  = cal.isDateInToday(date)
            let isFuture = date > Date()
            let hasRound = roundOnDay(date) != nil

            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isFuture ? Color.black.opacity(0.03) : cellColor(for: date))

                if isToday && !hasRound {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.28), lineWidth: 1.5)
                }

                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 10, weight: isToday ? .bold : .medium))
                    .foregroundStyle(
                        isFuture ? Color.black.opacity(0.15) :
                        hasRound ? Color.white :
                        Color.black.opacity(0.45)
                    )
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
        }
    }

    // MARK: - Year calendar

    private var yearCalendarView: some View {
        let cols = yearColumns
        let gap: CGFloat = 1.5
        let monthLabels = yearMonthPositions(in: cols)

        return GeometryReader { geo in
            let totalWidth = geo.size.width
            let cellSize = (totalWidth - CGFloat(cols.count - 1) * gap) / CGFloat(cols.count)
            let step = cellSize + gap

            VStack(alignment: .leading, spacing: 2) {
                // Month labels
                ZStack(alignment: .leading) {
                    Color.clear.frame(height: 12)
                    ForEach(monthLabels, id: \.col) { item in
                        Text(item.label)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.38))
                            .position(x: CGFloat(item.col) * step + cellSize / 2,
                                      y: 6)
                    }
                }

                // Grid
                HStack(alignment: .top, spacing: gap) {
                    ForEach(0..<cols.count, id: \.self) { col in
                        VStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { row in
                                if let date = cols[col][row] {
                                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                        .fill(yearCellColor(for: date))
                                        .frame(width: cellSize, height: cellSize)
                                } else {
                                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                        .fill(Color.black.opacity(0.04))
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(height: yearGridHeight)
    }

    private var yearGridHeight: CGFloat {
        // Approximate: 12 (month labels) + 2 (spacing) + 7 cells + 6 gaps
        // Cell ≈ (cardInnerWidth) / colCount.  Card ~350pt inner, ~53 cols → ~6pt cells
        let approxCell: CGFloat = 6.0
        let gap: CGFloat = 1.5
        return 12 + 2 + 7 * approxCell + 6 * gap + 2
    }

    /// Color for year grid — future dates get a very faint fill, past dates get normal coloring
    private func yearCellColor(for date: Date) -> Color {
        if date > Date() { return Color.black.opacity(0.04) }
        guard let round = roundOnDay(date) else { return Color.black.opacity(0.10) }
        return round.totalScore <= barAvg
            ? Color(red: 0.353, green: 0.620, blue: 0.365)
            : Color.black.opacity(0.78)
    }

    /// Returns (column index, month label) for each month boundary in the year grid
    private func yearMonthPositions(in cols: [[Date?]]) -> [(col: Int, label: String)] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        var result: [(col: Int, label: String)] = []
        var lastMonth = -1
        for (i, week) in cols.enumerated() {
            guard let firstDate = week.compactMap({ $0 }).first else { continue }
            let m = cal.component(.month, from: firstDate)
            if m != lastMonth {
                result.append((col: i, label: fmt.string(from: firstDate)))
                lastMonth = m
            }
        }
        return result
    }

    // MARK: - Calendar helpers

    private func roundOnDay(_ date: Date) -> CompletedRound? {
        rounds.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func cellColor(for date: Date) -> Color {
        guard let round = roundOnDay(date) else { return Color.black.opacity(0.08) }
        return round.totalScore <= barAvg
            ? Color(red: 0.353, green: 0.620, blue: 0.365)
            : Color.black.opacity(0.78)
    }

    private func monthDays(for month: Date) -> [Date?] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        guard let first = cal.date(from: comps) else { return [] }
        let weekday = cal.component(.weekday, from: first) - 1
        let range   = cal.range(of: .day, in: .month, for: first)!
        var days: [Date?] = Array(repeating: nil, count: weekday)
        for d in 0..<range.count {
            days.append(cal.date(byAdding: .day, value: d, to: first))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var yearColumns: [[Date?]] {
        let cal  = Calendar.current
        let year = selectedYear

        guard let jan1  = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let dec31 = cal.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return [] }

        // Start grid on the Sunday on or before Jan 1
        let jan1Dow = cal.component(.weekday, from: jan1) - 1
        guard let gridStart = cal.date(byAdding: .day, value: -jan1Dow, to: jan1) else { return [] }

        var cols: [[Date?]] = []
        var weekStart = gridStart

        while true {
            var week: [Date?] = []
            for d in 0..<7 {
                guard let day = cal.date(byAdding: .day, value: d, to: weekStart) else {
                    week.append(nil); continue
                }
                // Only include dates in this year
                if cal.component(.year, from: day) == year {
                    week.append(day)
                } else {
                    week.append(nil)
                }
            }
            cols.append(week)
            guard let nextWeek = cal.date(byAdding: .day, value: 6, to: weekStart) else { break }
            if nextWeek >= dec31 { break }
            weekStart = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
        }
        return cols
    }

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    // MARK: - In Progress card

    private func inProgressCard(round: ActiveRoundData) -> some View {
        Button(action: { showResume = true }) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: round.course.accentColors,
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
                    HStack {
                        Text("IN PROGRESS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .kerning(1.2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.18)))
                        Spacer()
                        let delta = round.scoreVsPar
                        let label = delta == 0 ? "E" : (delta > 0 ? "+\(delta)" : "\(delta)")
                        let bg: Color = delta < 0
                            ? Color(red: 0.486, green: 0.718, blue: 0.498)
                            : delta == 0 ? Color.white.opacity(0.20)
                            : Color(red: 0.88, green: 0.28, blue: 0.24)
                        Text(label)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .frame(width: 44, height: 36)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(bg))
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 5) {
                        Text(round.course.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                        HStack(spacing: 12) {
                            Label("Hole \(round.currentHole.number) of \(round.holes.count)", systemImage: "flag.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                            Label("\(round.playedCount) played", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }

                    HStack(alignment: .center) {
                        HStack(spacing: 5) {
                            Text("Resume Round")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.18)))

                        Spacer()

                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.80))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 212)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
    }
}
