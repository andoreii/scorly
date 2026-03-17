//
// CoursesView.swift
// Wallet-style course stack — choose a course to start a round.
//

import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var roundStore: RoundStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var courses: [Course] = []
    @State private var fetchedRounds: [CompletedRound] = []
    @State private var isLoadingCourses = true
    @State private var loadError: String?
    private let cardHeight: CGFloat = 212
    private let collapsedStep: CGFloat = 62
    private let detailsSpacing: CGFloat = 0
    private let detailsHeight: CGFloat = 420
    private let detailFadeDuration: Double = 0.32
    private let headerHeight: CGFloat = 44
    private let selectedCardLift: CGFloat = 0
    private let belowCardsExitOffset: CGFloat = 920

    // Snappy wallet spring
    private var walletSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.86)
    }

    @State private var activeCourseID: Course.ID?
    @State private var detailCourseID: Course.ID?
    @State private var presentedCourseInfo: Course?
    @State private var presentedRoundSetup: Course?
    @State private var presentedResumeRound = false
    @State private var presentedAddCourse = false
    @State private var presentedRoundDetail: CompletedRound? = nil
    @State private var presentedEditCourse: Course? = nil
    @State private var showDeleteConfirm = false
    @State private var showRoundInProgressPopup = false
    @State private var pendingStartCourse: Course?
    @State private var animationToken = UUID()
    @State private var promotedCardID: Course.ID? = nil

    var body: some View {
        ZStack {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    titleBlock.zIndex(1)
                    content.zIndex(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .refreshable {
                await loadCourses()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDisabled(activeCourseID != nil)

            if showRoundInProgressPopup {
                RoundInProgressPopup(
                    currentCourseName: roundStore.activeRound?.course.name ?? "Current Course",
                    nextCourseName: pendingStartCourse?.name ?? "Selected Course",
                    onResume: {
                        pendingStartCourse = nil
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showRoundInProgressPopup = false
                        }
                        presentedResumeRound = true
                    },
                    onDeleteAndStartNew: {
                        let nextCourse = pendingStartCourse
                        pendingStartCourse = nil
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showRoundInProgressPopup = false
                        }
                        roundStore.deleteRound()
                        if let nextCourse {
                            presentedRoundSetup = nextCourse
                        }
                    },
                    onCancel: {
                        pendingStartCourse = nil
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showRoundInProgressPopup = false
                        }
                    }
                )
                .zIndex(99)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: showRoundInProgressPopup)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: roundStore.pendingDismissToHome) { _, triggered in
            guard triggered else { return }
            dismissRoundFlow()
        }
        .onChange(of: roundStore.pendingDismissToRounds) { _, triggered in
            guard triggered else { return }
            dismissRoundFlow()
        }
        .sheet(item: $presentedCourseInfo) { course in
            CourseInfoSheet(course: course)
        }
        .fullScreenCover(item: $presentedRoundSetup) { course in
            RoundFlowView(course: course)
                .environmentObject(roundStore)
        }
        .fullScreenCover(isPresented: $presentedResumeRound) {
            if let round = roundStore.activeRound {
                NavigationStack {
                    RoundTrackerView(resumingFrom: round)
                }
                .environmentObject(roundStore)
            }
        }
        .task { await loadCourses() }
        .onAppear {
            Task { await loadCourses() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await loadCourses() }
        }
        .sheet(isPresented: $presentedAddCourse) {
            AddCourseSheet { newCourse in
                courses.insert(newCourse, at: 0)
            }
        }
        .sheet(item: $presentedRoundDetail) { round in
            RoundDetailView(round: round)
        }
        .sheet(item: $presentedEditCourse) { course in
            EditCourseSheet(course: course) { updatedCourse in
                if let index = courses.firstIndex(where: { $0.databaseId == updatedCourse.databaseId }) {
                    courses[index] = updatedCourse
                }
                activeCourseID = updatedCourse.id
                detailCourseID = updatedCourse.id
            }
        }
        .alert("Delete Course", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                let courseToDelete = activeCourseID.flatMap { id in courses.first { $0.id == id } }
                closeSelectedCourse()
                if let course = courseToDelete, let dbId = course.databaseId {
                    courses.removeAll { $0.id == course.id }
                    Task { try? await DataService.shared.deleteCourse(courseId: dbId) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let id = activeCourseID, let course = courses.first(where: { $0.id == id }) {
                Text("Are you sure you want to delete \"\(course.name)\"? This cannot be undone.")
            }
        }
    }

    private var background: some View {
        Color(red: 0.97, green: 0.97, blue: 0.98)
        .ignoresSafeArea()
    }

    private var titleBlock: some View {
        ZStack(alignment: .topLeading) {
            // Expanded state: Done + menu
            HStack {
                Button(action: closeSelectedCourse) {
                    Text("Done")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        guard let id = activeCourseID,
                              let course = courses.first(where: { $0.id == id })
                        else { return }
                        presentedEditCourse = course
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.55))
                            .frame(width: 34, height: 34)
                            .background(.white, in: Circle())
                            .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.80, green: 0.18, blue: 0.14))
                            .frame(width: 34, height: 34)
                            .background(.white, in: Circle())
                            .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: headerHeight)
            .opacity(detailCourseID == nil ? 0 : 1)
            .allowsHitTesting(detailCourseID != nil)

            // Collapsed state: title + add button
            HStack {
                Text("Courses")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.black)
                Spacer()
                Button(action: { presentedAddCourse = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.45))
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.05), in: Circle())
                        .overlay(Circle().strokeBorder(.black.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .opacity(activeCourseID == nil ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.22), value: activeCourseID)
        .padding(.bottom, 20)
    }

    private var cardStack: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                let isSelected = activeCourseID == course.id

                CourseCardView(course: course, isSelected: isSelected, onInfo: { presentedCourseInfo = course })
                    .offset(y: cardOffset(for: index))
                    .opacity(cardOpacity(for: index, isSelected: isSelected))
                    .scaleEffect(cardScale(for: index, isSelected: isSelected), anchor: .top)
                    .rotation3DEffect(
                        .degrees(cardTilt(for: index, isSelected: isSelected)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.4
                    )
                    .zIndex(cardZIndex(for: index, isSelected: isSelected))
                    .animation(
                        {
                            guard let activeID = activeCourseID,
                                  let selIdx = courses.firstIndex(where: { $0.id == activeID }) else {
                                // Collapsing — all cards spring back
                                return walletSpring.delay(cardAnimationDelay(for: index))
                            }
                            if isSelected {
                                // Bouncier spring for selected card sliding up
                                // (top card is already at 0, so no visible bounce needed)
                                if selIdx == 0 {
                                    return walletSpring
                                }
                                return .spring(response: 0.42, dampingFraction: 0.72)
                            }
                            if index < selIdx {
                                // Cards above: fast fade out
                                return .easeOut(duration: 0.12)
                            }
                            // Cards below: smooth spring slide down, staggered
                            let belowDistance = index - selIdx
                            return walletSpring.delay(Double(belowDistance) * 0.04)
                        }(),
                        value: activeCourseID
                    )
                    .onTapGesture {
                        handleTap(for: course)
                    }
                    .allowsHitTesting(activeCourseID == nil || isSelected)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                    .accessibilityLabel("\(course.name), \(course.location)")
            }

            if let activeCourse = courses.first(where: { $0.id == activeCourseID }) {
                courseDetails(for: activeCourse)
                    .offset(y: detailsOffset(for: activeCourse))
                    .zIndex(200)
                    .opacity(detailCourseID == nil ? 0 : 1)
                    .animation(.easeInOut(duration: detailFadeDuration), value: detailCourseID)
            }
        }
        .frame(height: stackHeight, alignment: .topLeading)
        .padding(.bottom, 36)
    }

    @ViewBuilder
    private var content: some View {
        if isLoadingCourses {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if courses.isEmpty {
            emptyState
                .padding(.top, 20)
        } else {
            cardStack
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No courses yet")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)

            Text(loadError ?? "Add your first course to get started.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var selectedCourse: Course? {
        guard let detailCourseID else { return nil }
        return courses.first(where: { $0.id == detailCourseID })
    }

    private var stackHeight: CGFloat {
        let belowCount = max(0, courses.count - 1)
        return cardHeight + detailsSpacing + detailsHeight + 16 + CGFloat(belowCount) * collapsedStep + cardHeight
    }

    private func baseOffset(for index: Int) -> CGFloat {
        CGFloat(index) * collapsedStep
    }

    private func cardOffset(for index: Int) -> CGFloat {
        let base = baseOffset(for: index)

        guard let activeCourseID, let selectedIndex = courses.firstIndex(where: { $0.id == activeCourseID }) else {
            return base
        }

        // Selected card: goes to top (offset 0)
        if index == selectedIndex { return 0 }

        if index < selectedIndex {
            // Cards ABOVE selected: slide up but clamp so they never go above offset 0
            // They tuck behind the selected card
            let target = max(0, base - CGFloat(selectedIndex - index) * 8)
            return target
        }

        // Cards BELOW selected: stack beneath the details area like a wallet
        let below = index - selectedIndex
        return cardHeight + detailsSpacing + detailsHeight + 16 + CGFloat(below - 1) * collapsedStep
    }

    private func cardZIndex(for index: Int, isSelected: Bool) -> Double {
        // Keep natural stacking order. Only promote the selected card
        // AFTER animations have started (via delayed promotedCardID).
        let course = courses[index]
        if course.id == promotedCardID { return Double(courses.count + 1) }
        return Double(index)
    }

    private func cardOpacity(for index: Int, isSelected: Bool) -> Double {
        guard let activeID = activeCourseID,
              let selectedIndex = courses.firstIndex(where: { $0.id == activeID }) else {
            return 1
        }
        if isSelected { return 1 }
        // Cards above: fade out
        if index < selectedIndex { return 0 }
        // Cards below: fade out as they slide down
        return 0
    }

    private func cardScale(for index: Int, isSelected: Bool) -> CGFloat {
        guard activeCourseID != nil else {
            // Collapsed stack: subtle depth — front cards full size, behind slightly smaller
            let maxIndex = max(courses.count - 1, 0)
            let depthFromFront = maxIndex - index
            return 1.0 - CGFloat(depthFromFront) * 0.012
        }
        if isSelected { return 1 }
        return 0.94
    }

    /// Subtle forward tilt on non-selected cards for parallax depth
    private func cardTilt(for index: Int, isSelected: Bool) -> Double {
        return 0
    }

    /// Stagger animation delay so cards ripple outward from selected card
    private func cardAnimationDelay(for index: Int) -> Double {
        guard let activeID = activeCourseID,
              let selectedIndex = courses.firstIndex(where: { $0.id == activeID }) else {
            return 0
        }
        let distance = abs(index - selectedIndex)
        return Double(distance) * 0.018
    }

    private func detailsOffset(for course: Course) -> CGFloat {
        cardHeight + detailsSpacing - selectedCardLift
    }

    private func handleTap(for course: Course) {
        let token = UUID()
        animationToken = token

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if activeCourseID == course.id {
            // Collapsing: clear promotion immediately, then animate
            promotedCardID = nil
            withAnimation(.easeOut(duration: 0.10)) {
                detailCourseID = nil
            }
            withAnimation(walletSpring) {
                activeCourseID = nil
            }
            return
        }

        detailCourseID = nil
        // Start the card animations first with natural z-order
        withAnimation(walletSpring) {
            activeCourseID = course.id
        }

        // Promote selected card's z-index after other cards have begun moving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            guard animationToken == token, activeCourseID == course.id else { return }
            promotedCardID = course.id
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            guard animationToken == token, activeCourseID == course.id else { return }
            withAnimation(.easeInOut(duration: detailFadeDuration)) {
                detailCourseID = course.id
            }
        }
    }

    private func closeSelectedCourse() {
        guard let activeCourseID,
              let course = courses.first(where: { $0.id == activeCourseID })
        else { return }
        handleTap(for: course)
    }

    private func dismissRoundFlow() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            presentedRoundSetup = nil
            presentedResumeRound = false
            presentedCourseInfo = nil
            presentedEditCourse = nil
            presentedRoundDetail = nil
            showRoundInProgressPopup = false
            pendingStartCourse = nil
            activeCourseID = nil
            detailCourseID = nil
            promotedCardID = nil
        }
    }

    private func attemptStartRound(for course: Course) {
        guard roundStore.activeRound != nil else {
            presentedRoundSetup = course
            return
        }

        pendingStartCourse = course
        withAnimation(.easeInOut(duration: 0.18)) {
            showRoundInProgressPopup = true
        }
    }

    private func loadCourses() async {
        loadError = nil

        do {
            let courseRows = try await DataService.shared.fetchCourses()
            courses = courseRows.map { Course(from: $0) }

            do {
                let roundRows = try await DataService.shared.fetchRounds()
                courses = courseRows.map { Course(from: $0, rounds: roundRows) }
                let courseMap = Dictionary(uniqueKeysWithValues: courseRows.map { ($0.courseId, $0) })
                fetchedRounds = roundRows.compactMap { row in
                    guard let course = courseMap[row.courseId] else { return nil }
                    return CompletedRound(from: row, course: course)
                }
            } catch {
                fetchedRounds = []
                loadError = "Courses loaded, but round history could not be loaded."
                #if DEBUG
                print("CoursesView rounds fetch failed:", error)
                #endif
            }
        } catch {
            courses = []
            fetchedRounds = []
            loadError = "Could not load courses right now."
            #if DEBUG
            print("CoursesView courses fetch failed:", error)
            #endif
        }
        isLoadingCourses = false
    }

    private func courseDetails(for course: Course) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Play button — raised white
            Button(action: {
                guard let course = selectedCourse else { return }
                attemptStartRound(for: course)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Play")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            // Recent rounds
            if !completedRounds(for: course).isEmpty {
                Text("Recent Rounds")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
                    .kerning(0.5)
                    .padding(.top, 14)

                VStack(spacing: 0) {
                    ForEach(Array(completedRounds(for: course).enumerated()), id: \.element.id) { idx, round in
                        if idx > 0 {
                            Divider().padding(.horizontal, 16)
                        }
                        styledRoundRow(round: round)
                            .onTapGesture { presentedRoundDetail = round }
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func completedRounds(for course: Course) -> [CompletedRound] {
        fetchedRounds
            .filter { $0.courseName == course.name }
            .sorted { $0.date > $1.date }
    }

    private func styledRoundRow(round: CompletedRound) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(round.scoreVsParText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(round.scoreColor)
                    .monospacedDigit()
                Text("\(round.totalScore)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
                    .monospacedDigit()
            }
            .frame(width: 46)

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(width: 1, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(round.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                HStack(spacing: 4) {
                    Text(round.roundType)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.45))
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.25))
                    Text(round.format)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.45))
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.25))
                    Text(round.tee)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.45))
                    if let notes = round.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "note.text")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.black.opacity(0.35))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black.opacity(0.22))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct RoundInProgressPopup: View {
    let currentCourseName: String
    let nextCourseName: String
    let onResume: () -> Void
    let onDeleteAndStartNew: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.black.opacity(0.20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
                .padding(.top, 16)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.486, green: 0.718, blue: 0.498).opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "flag.pattern.checkered.2.crossed")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.486, green: 0.718, blue: 0.498))
                }

                Text("Round In Progress")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 16)

                Text("You already have a round at \(currentCourseName). Resume it, or delete it and start a new round at \(nextCourseName).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    Button(action: onResume) {
                        Text("Resume Round")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onDeleteAndStartNew) {
                        Text("Delete Round")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.88, green: 0.28, blue: 0.24))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.18), radius: 30, y: 10)
            )
            .transition(.scale(scale: 0.88).combined(with: .opacity))
        }
    }
}

// MARK: - Course info sheet

private struct CourseInfoSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    private var frontNine: [CourseHole] { Array(course.holes.prefix(9)) }
    private var backNine:  [CourseHole] { Array(course.holes.dropFirst(9)) }

    private func parTotal(_ holes: [CourseHole]) -> Int     { holes.reduce(0) { $0 + $1.par } }
    private func ydsTotal(_ holes: [CourseHole], _ t: Int) -> Int { holes.reduce(0) { $0 + $1.yardages[t] } }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                header
                VStack(spacing: 14) {
                    statRow
                    teeRatingsCard
                    scorecardCard(title: "Front Nine", label: "OUT", holes: frontNine)
                    scorecardCard(title: "Back Nine",  label: "IN",  holes: backNine)
                    totalCard
                }
                .padding(20)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
    }

    private var header: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: course.accentColors, startPoint: .leading, endPoint: .trailing)
                .overlay(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .center))
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.22), in: Circle())
            }
            .padding(.top, 16).padding(.trailing, 16)
            VStack(alignment: .leading, spacing: 5) {
                Text(course.name)
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    .minimumScaleFactor(0.75).lineLimit(2)
                Text(course.location)
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.70))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22).padding(.top, 60).padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Par",     value: "\(course.par)")
            statCard(title: "Yardage", value: "\(course.yardage)")
            statCard(title: "Holes",   value: "\(course.holes.count)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.black.opacity(0.45))
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity).frame(height: 72).background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private var teeRatingsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("TEE").frame(maxWidth: .infinity, alignment: .leading)
                Text("RATING").frame(width: 72, alignment: .center)
                Text("SLOPE").frame(width: 64, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.black.opacity(0.35))
            .padding(.horizontal, 16).padding(.vertical, 11)
            Divider().padding(.horizontal, 16)
            ForEach(Array(course.tees.enumerated()), id: \.element.id) { index, tee in
                HStack(spacing: 0) {
                    Text(tee.name).frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f", tee.rating)).frame(width: 72, alignment: .center)
                    Text("\(tee.slope)").frame(width: 64, alignment: .trailing)
                }
                .font(.system(size: 15, weight: .regular)).foregroundStyle(.black)
                .padding(.horizontal, 16).padding(.vertical, 11)
                if index < course.tees.count - 1 { Divider().padding(.leading, 16) }
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func scorecardCard(title: String, label: String, holes: [CourseHole]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.black.opacity(0.38))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            scorecardRow("HOLE", hcp: "HCP", t0: course.tees[0].name.prefix(4).uppercased(),
                         t1: course.tees[1].name.prefix(4).uppercased(),
                         t2: course.tees[2].name.prefix(3).uppercased(), par: "PAR", style: .header)
            Divider().padding(.horizontal, 16)
            ForEach(Array(holes.enumerated()), id: \.element.id) { index, hole in
                scorecardRow("\(hole.number)", hcp: "\(hole.handicap)",
                             t0: "\(hole.yardages[0])", t1: "\(hole.yardages[1])", t2: "\(hole.yardages[2])",
                             par: "\(hole.par)", style: .normal)
                if index < holes.count - 1 { Divider().padding(.leading, 16) }
            }
            Divider().padding(.horizontal, 16)
            scorecardRow(label, hcp: "",
                         t0: "\(ydsTotal(holes, 0))", t1: "\(ydsTotal(holes, 1))", t2: "\(ydsTotal(holes, 2))",
                         par: "\(parTotal(holes))", style: .subtotal)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private enum RowStyle { case header, normal, subtotal }

    private func scorecardRow(_ hole: String, hcp: String,
                               t0: any StringProtocol, t1: any StringProtocol, t2: any StringProtocol,
                               par: String, style: RowStyle) -> some View {
        HStack(spacing: 0) {
            Text(hole).frame(width: 52, alignment: .leading).lineLimit(1)
            Text(hcp).frame(width: 28, alignment: .center).lineLimit(1)
            Text(t0).frame(maxWidth: .infinity, alignment: .center).lineLimit(1)
            Text(t1).frame(maxWidth: .infinity, alignment: .center).lineLimit(1)
            Text(t2).frame(maxWidth: .infinity, alignment: .center).lineLimit(1)
            Text(par).frame(width: 36, alignment: .trailing).lineLimit(1)
        }
        .font(style == .header   ? .system(size: 10, weight: .semibold)
            : style == .subtotal ? .system(size: 14, weight: .bold)
            :                      .system(size: 14, weight: .regular))
        .foregroundStyle(style == .header ? .black.opacity(0.35) : .black)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(style == .subtotal ? Color.black.opacity(0.03) : Color.clear)
    }

    private var totalCard: some View {
        HStack(spacing: 0) {
            Text("TOTAL").frame(width: 52, alignment: .leading).lineLimit(1)
            Text("").frame(width: 28)
            Text("\(ydsTotal(course.holes, 0))").frame(maxWidth: .infinity, alignment: .center).lineLimit(1)
            Text("\(ydsTotal(course.holes, 1))").frame(maxWidth: .infinity, alignment: .center).lineLimit(1)
            Text("\(ydsTotal(course.holes, 2))").frame(maxWidth: .infinity, alignment: .center).lineLimit(1)
            Text("\(course.par)").frame(width: 36, alignment: .trailing).lineLimit(1)
        }
        .font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }
}
