//
// CoursesView.swift
// Wallet-style course stack — choose a course to start a round.
//

import SwiftUI

struct CoursesView: View {
    private struct RoundTrackerLaunch: Identifiable {
        let id = UUID()
        let course: Course
        let payload: RoundSetupView.StartPayload
    }

    @EnvironmentObject var roundStore: RoundStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabMotionCoordinator.self) private var tabMotion

    @State private var courses: [Course] = []
    @State private var fetchedRounds: [CompletedRound] = []
    @State private var isLoadingCourses = true
    @State private var loadError: String?
    private let cardHeight: CGFloat = 212
    private let collapsedStep: CGFloat = 62
    private let baseDetailsHeight: CGFloat = 420
    private let roundSetupDetailsHeight: CGFloat = 880
    private let roundSetupAttachmentOffset: CGFloat = 52
    private let detailFadeDuration: Double = 0.32
    private let headerHeight: CGFloat = 44
    private let selectedCardLift: CGFloat = 0
    private let belowCardsExitOffset: CGFloat = 920
    private let modeSwapMountDelay: Double = 0.02
    private let courseExitStagger: Double = 0.03
    private let courseEnterStagger: Double = 0.04
    private let sectionSwapStagger: Double = 0.045

    // Snappy wallet spring
    private var walletSpring: Animation {
        Theme.Animation.smooth
    }

    @State private var activeCourseID: Course.ID?
    @State private var detailCourseID: Course.ID?
    @State private var detailsAppeared = false
    @State private var presentedCourseInfo: Course?
    @State private var presentedRoundTrackerLaunch: RoundTrackerLaunch? = nil
    @State private var presentedResumeRound = false
    @State private var presentedAddCourse = false
    @State private var presentedRoundDetail: CompletedRound? = nil
    @State private var showDeleteConfirm = false
    @State private var showRoundInProgressPopup = false
    @State private var pendingStartCourse: Course?
    @State private var animationToken = UUID()
    @State private var promotedCardID: Course.ID? = nil
    @State private var renderCourseBrowser = true
    @State private var courseBrowserVisible = true
    @State private var renderAddCourseComposer = false
    @State private var addCourseComposerVisible = false
    @State private var addCourseTransitionToken = 0
    @State private var isAddCourseTransitioning = false
    @State private var isEditingSelectedCourse = false
    @State private var renderEditCourseComposer = false
    @State private var editCourseComposerVisible = false
    @State private var editCourseTransitionToken = 0
    @State private var isEditCourseTransitioning = false
    @State private var isSettingUpSelectedCourse = false
    @State private var renderRoundSetupComposer = false
    @State private var roundSetupComposerVisible = false
    @State private var roundSetupTransitionToken = 0
    @State private var isRoundSetupTransitioning = false
    @State private var roundSetupDraftPayload: RoundSetupView.StartPayload? = nil
    @State private var isSelectedCourseMenuExpanded = false

    var body: some View {
        ZStack {
            background

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        titleBlock(scrollProxy: scrollProxy)
                            .tabReveal(tab: 1, order: 0)
                            .zIndex(1)
                            .id("coursesTop")
                        content.zIndex(0)
                    }
                    .padding(.horizontal, Theme.Spacing.pageHorizontal)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
                .refreshable {
                    await loadCourses()
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(activeCourseID != nil && !renderRoundSetupComposer)
                .onChange(of: activeCourseID) { _, newValue in
                    if newValue != nil {
                        withAnimation(walletSpring) {
                            scrollProxy.scrollTo("coursesTop", anchor: .top)
                        }
                    }
                }
            }

            if showRoundInProgressPopup {
                RoundInProgressPopup(
                    currentCourseName: roundStore.activeRound?.course.name ?? "Current Course",
                    nextCourseName: pendingStartCourse?.name ?? "Selected Course",
                    onResume: {
                        pendingStartCourse = nil
                        withAnimation(Theme.Animation.snappy) {
                            showRoundInProgressPopup = false
                        }
                        presentedResumeRound = true
                    },
                    onDeleteAndStartNew: {
                        let nextCourse = pendingStartCourse
                        pendingStartCourse = nil
                        withAnimation(Theme.Animation.snappy) {
                            showRoundInProgressPopup = false
                        }
                        roundStore.deleteRound()
                        if let nextCourse {
                            openRoundSetupComposer(for: nextCourse)
                        }
                    },
                    onCancel: {
                        pendingStartCourse = nil
                        withAnimation(Theme.Animation.snappy) {
                            showRoundInProgressPopup = false
                        }
                    }
                )
                .zIndex(99)
                .transition(.opacity)
                .animation(Theme.Animation.snappy, value: showRoundInProgressPopup)
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
        .fullScreenCover(item: $presentedRoundTrackerLaunch) { launch in
            RoundTrackerView(
                course: launch.course,
                datePlayed: launch.payload.datePlayed,
                holesOption: launch.payload.holesOption,
                teeIndex: launch.payload.teeIndex,
                notes: launch.payload.notes,
                conditions: launch.payload.conditions,
                temperature: launch.payload.temperature,
                roundType: launch.payload.roundType,
                roundFormat: launch.payload.roundFormat,
                transport: launch.payload.transport,
                mentalState: launch.payload.mentalState
            )
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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await loadCourses() }
        }
        .sheet(item: $presentedRoundDetail) { round in
            RoundDetailView(round: round)
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
        Theme.Colors.canvas
        .ignoresSafeArea()
    }

    private func titleBlock(scrollProxy: ScrollViewProxy) -> some View {
        HStack(alignment: .center) {
            ZStack(alignment: .leading) {
                courseTitleGroup
                    .scaleEffect(activeCourseID == nil ? 1 : 0.48, anchor: .leading)
                    .opacity(activeCourseID == nil ? 1 : 0)
                    .allowsHitTesting(activeCourseID == nil)

                Button(action: closeSelectedCourse) {
                    Text("Done")
                        .font(Theme.Typography.title2)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .buttonStyle(ScorlyPressStyle())
                .padding(.top, 4)
                .scaleEffect(activeCourseID == nil || isEditingSelectedCourse || isSettingUpSelectedCourse ? 1.18 : 1, anchor: .leading)
                .opacity(activeCourseID != nil && !isEditingSelectedCourse && !isSettingUpSelectedCourse ? 1 : 0)
                .allowsHitTesting(activeCourseID != nil && !isEditingSelectedCourse && !isSettingUpSelectedCourse)
                .offset(y: activeCourseID != nil && !isEditingSelectedCourse && !isSettingUpSelectedCourse ? 0 : 5)

                Text("Edit Course")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, 4)
                    .scaleEffect(isEditingSelectedCourse ? 1 : 0.92, anchor: .leading)
                    .opacity(isEditingSelectedCourse ? 1 : 0)
                    .allowsHitTesting(false)
                    .offset(y: isEditingSelectedCourse ? 0 : -5)

                Text("Round Setup")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, 4)
                    .scaleEffect(isSettingUpSelectedCourse ? 1 : 0.92, anchor: .leading)
                    .opacity(isSettingUpSelectedCourse ? 1 : 0)
                    .allowsHitTesting(false)
                    .offset(y: isSettingUpSelectedCourse ? 0 : -5)
            }

            Spacer()

            trailingHeaderControl(scrollProxy: scrollProxy)
        }
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity)
        .animation(Theme.Animation.snappy, value: activeCourseID)
        .animation(Theme.Animation.snappy, value: isEditingSelectedCourse)
        .animation(Theme.Animation.snappy, value: isSettingUpSelectedCourse)
        .animation(Theme.Animation.smooth, value: isSelectedCourseMenuExpanded)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var courseTitleGroup: some View {
        ZStack(alignment: .leading) {
            if renderCourseBrowser {
                Text("Courses")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .opacity(courseBrowserVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.12), value: courseBrowserVisible)
            }

            if renderAddCourseComposer {
                Text("Add Course")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .opacity(addCourseComposerVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.16), value: addCourseComposerVisible)
            }
        }
    }

    @ViewBuilder
    private func trailingHeaderControl(scrollProxy: ScrollViewProxy) -> some View {
        let isCourseSelected = activeCourseID != nil
        let isMenuExpanded = isCourseSelected && !isEditingSelectedCourse && !isSettingUpSelectedCourse && isSelectedCourseMenuExpanded
        let controlWidth: CGFloat = isMenuExpanded ? 126 : 34
        let showsCloseGlyph = (isEditingSelectedCourse || isSettingUpSelectedCourse) || (presentedAddCourse && !isCourseSelected)
        let trailingSymbol = showsCloseGlyph ? "xmark" : (isCourseSelected ? "ellipsis" : "plus")

        ZStack(alignment: .trailing) {
            Capsule()
                .fill(Theme.Colors.surface)
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
                )
                .themeShadow(Theme.Shadow.subtle)

            if isMenuExpanded {
                HStack(spacing: 0) {
                    actionMenuButton(icon: "info.circle", tint: Theme.Colors.textSecondary) {
                        guard let id = activeCourseID,
                              let course = courses.first(where: { $0.id == id }) else { return }
                        withAnimation(Theme.Animation.snappy) {
                            isSelectedCourseMenuExpanded = false
                        }
                        presentedCourseInfo = course
                    }

                    actionMenuDivider

                    actionMenuButton(icon: "pencil", tint: Theme.Colors.textSecondary) {
                        guard let id = activeCourseID,
                              let course = courses.first(where: { $0.id == id }) else { return }
                        withAnimation(Theme.Animation.snappy) {
                            isSelectedCourseMenuExpanded = false
                        }
                        openEditCourseComposer(for: course)
                    }

                    actionMenuDivider

                    actionMenuButton(icon: "trash", tint: Theme.Colors.error) {
                        withAnimation(Theme.Animation.snappy) {
                            isSelectedCourseMenuExpanded = false
                        }
                        showDeleteConfirm = true
                    }
                }
                .padding(.horizontal, 2)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
            } else {
                Button(action: {
                    if isEditingSelectedCourse {
                        closeEditCourseComposer()
                    } else if isSettingUpSelectedCourse {
                        closeRoundSetupComposer()
                    } else if isCourseSelected {
                        withAnimation(Theme.Animation.smooth) {
                            isSelectedCourseMenuExpanded = true
                        }
                    } else {
                        guard !isAddCourseTransitioning && !isEditCourseTransitioning && !isRoundSetupTransitioning else { return }

                        if presentedAddCourse {
                            closeAddCourseComposer()
                        } else {
                            withAnimation(Theme.Animation.smooth) {
                                scrollProxy.scrollTo("coursesTop", anchor: .top)
                            }
                            openAddCourseComposer()
                        }
                    }
                }) {
                    ZStack {
                        Image(systemName: "ellipsis")
                            .opacity(trailingSymbol == "ellipsis" ? 1 : 0)
                            .scaleEffect(trailingSymbol == "ellipsis" ? 1 : 0.72)
                            .rotationEffect(.degrees(trailingSymbol == "ellipsis" ? 0 : -70))

                        Image(systemName: "plus")
                            .opacity(trailingSymbol == "plus" ? 1 : 0)
                            .scaleEffect(trailingSymbol == "plus" ? 1 : 0.72)
                            .rotationEffect(.degrees(trailingSymbol == "plus" ? 0 : -85))

                        Image(systemName: "xmark")
                            .opacity(trailingSymbol == "xmark" ? 1 : 0)
                            .scaleEffect(trailingSymbol == "xmark" ? 1 : 0.78)
                            .rotationEffect(.degrees(trailingSymbol == "xmark" ? 0 : 85))
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(ScorlyPressStyle())
                .disabled(isAddCourseTransitioning || isEditCourseTransitioning || isRoundSetupTransitioning)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
        }
        .frame(width: controlWidth, height: 34, alignment: .trailing)
        .animation(Theme.Animation.smooth, value: isMenuExpanded)
        .animation(Theme.Animation.snappy, value: presentedAddCourse)
        .animation(Theme.Animation.snappy, value: isEditingSelectedCourse)
        .animation(Theme.Animation.snappy, value: isSettingUpSelectedCourse)
        .animation(Theme.Animation.snappy, value: trailingSymbol)
    }

    private var actionMenuDivider: some View {
        Rectangle()
            .fill(Theme.Colors.whisperBorder)
            .frame(width: 1, height: 18)
    }

    private func actionMenuButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScorlyPressStyle())
    }

    private var cardStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                    let isSelected = activeCourseID == course.id

                    CourseCardView(course: course, isSelected: isSelected)
                        .sequencedVisibility(
                            index: min(index, maxCourseCascadeIndex),
                            isVisible: areCourseCardsVisible,
                            hiddenOffset: 28 + CGFloat(min(index, maxCourseCascadeIndex)) * 4,
                            hiddenScale: 0.998,
                            enterAnimation: Theme.Animation.bouncy,
                            exitAnimation: Theme.Animation.tabExit,
                            enterStagger: courseEnterStagger,
                            exitStagger: courseExitStagger
                        )
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
                                    return walletSpring.delay(cardAnimationDelay(for: index))
                                }
                                if isSelected {
                                    if selIdx == 0 {
                                        return walletSpring
                                    }
                                    return Theme.Animation.bouncy
                                }
                                if index < selIdx {
                                    return .easeOut(duration: 0.12)
                                }
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

                if let activeCourse = courses.first(where: { $0.id == activeCourseID }), !isRoundSetupDetailPresented {
                    courseDetails(for: activeCourse)
                        .offset(y: detailsOffset(for: activeCourse))
                        .zIndex(200)
                        .opacity(detailCourseID == nil ? 0 : 1)
                        .animation(.easeInOut(duration: detailFadeDuration), value: detailCourseID)
                }
            }
            .frame(height: cardStackBodyHeight, alignment: .topLeading)

            if let activeCourse = courses.first(where: { $0.id == activeCourseID }), isRoundSetupDetailPresented {
                Theme.Colors.canvas
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Spacing.sm)

                courseDetails(for: activeCourse)
                    .opacity(detailCourseID == nil ? 0 : 1)
                    .animation(.easeInOut(duration: detailFadeDuration), value: detailCourseID)
            }
        }
        .padding(.bottom, 36)
    }

    @ViewBuilder
    private var content: some View {
        ZStack(alignment: .top) {
            if renderCourseBrowser {
                courseBrowserContent
                    .allowsHitTesting(courseBrowserVisible)
            }

            if renderAddCourseComposer {
                addCourseComposer
                    .allowsHitTesting(addCourseComposerVisible)
            }
        }
    }

    @ViewBuilder
    private var courseBrowserContent: some View {
        if isLoadingCourses {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .sequencedVisibility(
                    index: 0,
                    isVisible: isCourseBrowserPresented,
                    hiddenOffset: 20,
                    hiddenScale: 0.994,
                    enterAnimation: Theme.Animation.bouncy,
                    exitAnimation: Theme.Animation.tabExit,
                    enterStagger: courseEnterStagger,
                    exitStagger: courseExitStagger
                )
        } else if courses.isEmpty {
            emptyState
                .padding(.top, Theme.Spacing.lg)
                .sequencedVisibility(
                    index: 0,
                    isVisible: isCourseBrowserPresented,
                    hiddenOffset: 20,
                    hiddenScale: 0.994,
                    enterAnimation: Theme.Animation.bouncy,
                    exitAnimation: Theme.Animation.tabExit,
                    enterStagger: courseEnterStagger,
                    exitStagger: courseExitStagger
                )
        } else {
            cardStack
        }
    }

    private var addCourseComposer: some View {
        AddCourseSheet(
            onDismiss: {
                closeAddCourseComposer()
            },
            onSave: { newCourse in
                courses.insert(newCourse, at: 0)
                closeAddCourseComposer()
            },
            presentationStyle: .embedded,
            isVisible: addCourseComposerVisible
        )
        .padding(.top, Theme.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("No courses yet")
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(loadError ?? "Add your first course to get started.")
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
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

    private var cardStackBodyHeight: CGFloat {
        isRoundSetupDetailPresented ? cardHeight : stackHeight
    }

    private var detailsSpacing: CGFloat {
        renderRoundSetupComposer ? Theme.Spacing.xl : 0
    }

    private var detailsHeight: CGFloat {
        renderRoundSetupComposer ? roundSetupDetailsHeight : baseDetailsHeight
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
        cardHeight + detailsSpacing + (renderRoundSetupComposer ? roundSetupAttachmentOffset : 0) - selectedCardLift
    }

    private var isRoundSetupDetailPresented: Bool {
        isSettingUpSelectedCourse || renderRoundSetupComposer
    }

    private func handleTap(for course: Course) {
        let token = UUID()
        animationToken = token
        isSelectedCourseMenuExpanded = false

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if activeCourseID == course.id {
            // Collapsing: clear promotion immediately, then animate
            editCourseTransitionToken += 1
            roundSetupTransitionToken += 1
            isEditCourseTransitioning = false
            isRoundSetupTransitioning = false
            isEditingSelectedCourse = false
            isSettingUpSelectedCourse = false
            renderEditCourseComposer = false
            editCourseComposerVisible = false
            renderRoundSetupComposer = false
            roundSetupComposerVisible = false
            roundSetupDraftPayload = nil
            promotedCardID = nil
            detailsAppeared = false
            withAnimation(.easeOut(duration: 0.10)) {
                detailCourseID = nil
            }
            withAnimation(walletSpring) {
                activeCourseID = nil
            }
            return
        }

        detailCourseID = nil
        detailsAppeared = false
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
            withAnimation(Theme.Animation.smooth.delay(0.1)) {
                detailsAppeared = true
            }
        }
    }

    private func closeSelectedCourse() {
        guard let activeCourseID,
              let course = courses.first(where: { $0.id == activeCourseID })
        else { return }
        handleTap(for: course)
    }

    private var isCourseBrowserPresented: Bool {
        renderCourseBrowser && courseBrowserVisible && tabMotion.activeTab == 1
    }

    private var areCourseCardsVisible: Bool {
        isCourseBrowserPresented
    }

    private var maxCourseCascadeIndex: Int {
        max(min(courses.count, 8) - 1, 0)
    }

    private var courseBrowserExitDuration: Double {
        0.22 + Double(maxCourseCascadeIndex) * courseExitStagger
    }

    private var courseBrowserEnterDuration: Double {
        0.34 + Double(maxCourseCascadeIndex) * courseEnterStagger
    }

    private var addComposerExitDuration: Double {
        0.24 + (5 * 0.03)
    }

    private var addComposerEnterDuration: Double {
        0.36 + (5 * sectionSwapStagger)
    }

    private var editComposerExitDuration: Double {
        0.24 + (4 * 0.03)
    }

    private var editComposerEnterDuration: Double {
        0.36 + (4 * sectionSwapStagger)
    }

    private var roundSetupComposerExitDuration: Double {
        0.24 + (5 * 0.03)
    }

    private var roundSetupComposerEnterDuration: Double {
        0.36 + (5 * sectionSwapStagger)
    }

    private func openAddCourseComposer() {
        guard !presentedAddCourse else { return }

        addCourseTransitionToken += 1
        let token = addCourseTransitionToken
        isAddCourseTransitioning = true
        isSelectedCourseMenuExpanded = false

        presentedAddCourse = true

        courseBrowserVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + courseBrowserExitDuration) {
            guard addCourseTransitionToken == token else { return }
            renderCourseBrowser = false
            renderAddCourseComposer = true
            addCourseComposerVisible = false

            DispatchQueue.main.asyncAfter(deadline: .now() + modeSwapMountDelay) {
                guard addCourseTransitionToken == token else { return }
                addCourseComposerVisible = true

                DispatchQueue.main.asyncAfter(deadline: .now() + addComposerEnterDuration) {
                    guard addCourseTransitionToken == token else { return }
                    isAddCourseTransitioning = false
                }
            }
        }
    }

    private func closeAddCourseComposer() {
        guard presentedAddCourse else { return }

        addCourseTransitionToken += 1
        let token = addCourseTransitionToken
        isAddCourseTransitioning = true
        isSelectedCourseMenuExpanded = false
        presentedAddCourse = false

        addCourseComposerVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + addComposerExitDuration) {
            guard addCourseTransitionToken == token else { return }
            renderAddCourseComposer = false
            renderCourseBrowser = true
            courseBrowserVisible = false

            DispatchQueue.main.asyncAfter(deadline: .now() + modeSwapMountDelay) {
                guard addCourseTransitionToken == token else { return }
                courseBrowserVisible = true

                DispatchQueue.main.asyncAfter(deadline: .now() + courseBrowserEnterDuration) {
                    guard addCourseTransitionToken == token else { return }
                    isAddCourseTransitioning = false
                }
            }
        }
    }

    private func detailSectionCount(for course: Course) -> Int {
        completedRounds(for: course).isEmpty ? 1 : 3
    }

    private func detailContentExitDuration(for course: Course) -> Double {
        0.18 + Double(max(detailSectionCount(for: course) - 1, 0)) * 0.03
    }

    private func detailContentEnterDuration(for course: Course) -> Double {
        0.28 + Double(max(detailSectionCount(for: course) - 1, 0)) * sectionSwapStagger
    }

    private func openEditCourseComposer(for course: Course) {
        guard !isEditCourseTransitioning else { return }

        editCourseTransitionToken += 1
        let token = editCourseTransitionToken
        isEditCourseTransitioning = true
        isSelectedCourseMenuExpanded = false
        isEditingSelectedCourse = true
        detailsAppeared = false

        DispatchQueue.main.asyncAfter(deadline: .now() + detailContentExitDuration(for: course)) {
            guard editCourseTransitionToken == token, activeCourseID == course.id else { return }
            renderEditCourseComposer = true
            editCourseComposerVisible = false

            DispatchQueue.main.asyncAfter(deadline: .now() + modeSwapMountDelay) {
                guard editCourseTransitionToken == token, activeCourseID == course.id else { return }
                editCourseComposerVisible = true

                DispatchQueue.main.asyncAfter(deadline: .now() + editComposerEnterDuration) {
                    guard editCourseTransitionToken == token else { return }
                    isEditCourseTransitioning = false
                }
            }
        }
    }

    private func closeEditCourseComposer() {
        guard isEditingSelectedCourse else { return }

        editCourseTransitionToken += 1
        let token = editCourseTransitionToken
        let currentCourse = selectedCourse
        isEditCourseTransitioning = true
        isSelectedCourseMenuExpanded = false
        editCourseComposerVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + editComposerExitDuration) {
            guard editCourseTransitionToken == token else { return }
            renderEditCourseComposer = false
            isEditingSelectedCourse = false
            detailsAppeared = false

            DispatchQueue.main.asyncAfter(deadline: .now() + modeSwapMountDelay) {
                guard editCourseTransitionToken == token else { return }
                detailsAppeared = true

                DispatchQueue.main.asyncAfter(deadline: .now() + (currentCourse.map(detailContentEnterDuration(for:)) ?? 0.28)) {
                    guard editCourseTransitionToken == token else { return }
                    isEditCourseTransitioning = false
                }
            }
        }
    }

    private func openRoundSetupComposer(for course: Course) {
        guard !isRoundSetupTransitioning else { return }

        roundSetupTransitionToken += 1
        let token = roundSetupTransitionToken
        isRoundSetupTransitioning = true
        isSelectedCourseMenuExpanded = false
        roundSetupDraftPayload = nil
        withAnimation(Theme.Animation.snappy) {
            isSettingUpSelectedCourse = true
            detailsAppeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + detailContentExitDuration(for: course)) {
            guard roundSetupTransitionToken == token, activeCourseID == course.id else { return }
            renderRoundSetupComposer = true
            roundSetupComposerVisible = false

            DispatchQueue.main.asyncAfter(deadline: .now() + modeSwapMountDelay) {
                guard roundSetupTransitionToken == token, activeCourseID == course.id else { return }
                withAnimation(Theme.Animation.bouncy) {
                    roundSetupComposerVisible = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + roundSetupComposerEnterDuration) {
                    guard roundSetupTransitionToken == token else { return }
                    isRoundSetupTransitioning = false
                }
            }
        }
    }

    private func closeRoundSetupComposer() {
        guard isSettingUpSelectedCourse else { return }

        roundSetupTransitionToken += 1
        let token = roundSetupTransitionToken
        let currentCourse = selectedCourse
        isRoundSetupTransitioning = true
        isSelectedCourseMenuExpanded = false
        withAnimation(Theme.Animation.tabExit) {
            roundSetupComposerVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + roundSetupComposerExitDuration) {
            guard roundSetupTransitionToken == token else { return }
            roundSetupDraftPayload = nil
            renderRoundSetupComposer = false
            withAnimation(Theme.Animation.snappy) {
                isSettingUpSelectedCourse = false
                detailsAppeared = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + modeSwapMountDelay) {
                guard roundSetupTransitionToken == token else { return }
                withAnimation(Theme.Animation.bouncy) {
                    detailsAppeared = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + (currentCourse.map(detailContentEnterDuration(for:)) ?? 0.28)) {
                    guard roundSetupTransitionToken == token else { return }
                    isRoundSetupTransitioning = false
                }
            }
        }
    }

    private func dismissRoundFlow() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            addCourseTransitionToken += 1
            editCourseTransitionToken += 1
            roundSetupTransitionToken += 1
            isAddCourseTransitioning = false
            isEditCourseTransitioning = false
            isRoundSetupTransitioning = false
            isSelectedCourseMenuExpanded = false
            presentedRoundTrackerLaunch = nil
            presentedResumeRound = false
            presentedCourseInfo = nil
            presentedRoundDetail = nil
            presentedAddCourse = false
            isEditingSelectedCourse = false
            isSettingUpSelectedCourse = false
            renderCourseBrowser = true
            courseBrowserVisible = true
            renderAddCourseComposer = false
            addCourseComposerVisible = false
            renderEditCourseComposer = false
            editCourseComposerVisible = false
            renderRoundSetupComposer = false
            roundSetupComposerVisible = false
            roundSetupDraftPayload = nil
            showRoundInProgressPopup = false
            pendingStartCourse = nil
            activeCourseID = nil
            detailCourseID = nil
            promotedCardID = nil
            detailsAppeared = false
        }
    }

    private func attemptStartRound(for course: Course) {
        guard roundStore.activeRound != nil else {
            openRoundSetupComposer(for: course)
            return
        }

        pendingStartCourse = course
        withAnimation(Theme.Animation.snappy) {
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
        let recentRounds = completedRounds(for: course)
        let isDetailContentVisible = detailsAppeared && !isEditingSelectedCourse && !isSettingUpSelectedCourse
        let isRoundSetupMode = isSettingUpSelectedCourse || renderRoundSetupComposer

        return VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                guard let course = selectedCourse else { return }

                if isRoundSetupMode {
                    guard let payload = roundSetupDraftPayload else { return }
                    presentedRoundTrackerLaunch = RoundTrackerLaunch(course: course, payload: payload)
                } else {
                    attemptStartRound(for: course)
                }
            }) {
                ZStack {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Play")
                            .font(Theme.Typography.caption)
                    }
                    .opacity(isRoundSetupMode ? 0 : 1)
                    .scaleEffect(isRoundSetupMode ? 0.92 : 1)
                    .offset(y: isRoundSetupMode ? 10 : 0)

                    HStack(spacing: 7) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Round")
                            .font(Theme.Typography.caption)
                    }
                    .opacity(isRoundSetupMode ? 1 : 0)
                    .scaleEffect(isRoundSetupMode ? 1 : 0.92)
                    .offset(y: isRoundSetupMode ? 0 : -10)
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.Colors.surface)
                        .themeShadow(Theme.Shadow.subtle)
                )
            }
            .buttonStyle(ScorlyPressStyle())
            .padding(.top, isRoundSetupMode ? 0 : Theme.Spacing.sm)
            .disabled(isRoundSetupMode && roundSetupDraftPayload == nil)
            .animation(Theme.Animation.snappy, value: isRoundSetupMode)

            if renderEditCourseComposer {
                ScrollView(.vertical, showsIndicators: false) {
                    AddCourseSheet(
                        onDismiss: {
                            closeEditCourseComposer()
                        },
                        onSave: { updatedCourse in
                            if let index = courses.firstIndex(where: { $0.databaseId == updatedCourse.databaseId }) {
                                courses[index] = updatedCourse
                            }
                            activeCourseID = updatedCourse.id
                            detailCourseID = updatedCourse.id
                        },
                        presentationStyle: .embedded,
                        isVisible: editCourseComposerVisible,
                        existingCourse: course,
                        showsPreviewHeader: false
                    )
                    .padding(.top, 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if renderRoundSetupComposer {
                RoundSetupView(
                    course: course,
                    onPayloadChange: { payload in
                        roundSetupDraftPayload = payload
                    },
                    presentationStyle: .embedded,
                    isVisible: roundSetupComposerVisible,
                    showsHeader: false,
                    showsCourseCard: false,
                    showsStartButton: false
                )
                .padding(.top, Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .top)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if !recentRounds.isEmpty {
                        Text("Recent Rounds")
                            .font(Theme.Typography.captionSmall)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .kerning(0.5)
                            .padding(.top, 14)
                            .sequencedVisibility(
                                index: 0,
                                isVisible: isDetailContentVisible,
                                hiddenOffset: 22,
                                hiddenScale: 0.998,
                                enterAnimation: Theme.Animation.bouncy,
                                exitAnimation: Theme.Animation.tabExit,
                                enterStagger: sectionSwapStagger,
                                exitStagger: 0.03
                            )

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(Array(recentRounds.enumerated()), id: \.element.id) { idx, round in
                                    if idx > 0 {
                                        Divider().padding(.horizontal, Theme.Spacing.md)
                                    }
                                    styledRoundRow(round: round)
                                        .onTapGesture { presentedRoundDetail = round }
                                }
                            }
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
                            .themeShadow(Theme.Shadow.subtle)
                            .padding(.top, 6)
                        }
                        .padding(.bottom, Theme.Spacing.xs)
                        .sequencedVisibility(
                            index: 1,
                            isVisible: isDetailContentVisible,
                            hiddenOffset: 26,
                            hiddenScale: 0.998,
                            enterAnimation: Theme.Animation.bouncy,
                            exitAnimation: Theme.Animation.tabExit,
                            enterStagger: sectionSwapStagger,
                            exitStagger: 0.03
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: detailsHeight)
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
                    .font(Theme.Typography.title2)
                    .foregroundStyle(round.scoreColor)
                    .monospacedDigit()
                Text("\(round.totalScore)")
                    .font(Theme.Typography.captionSmall)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
            }
            .frame(width: 46)

            Rectangle()
                .fill(Theme.Colors.whisperBorder)
                .frame(width: 1, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(round.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(Theme.Typography.bodySemibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 4) {
                    Text(round.roundType)
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("\u{00B7}")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(round.format)
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("\u{00B7}")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text(round.tee)
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if let notes = round.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "note.text")
                            .font(.system(size: 10, weight: .medium))
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
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
                .padding(.trailing, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)

                ZStack {
                    Circle()
                        .fill(Theme.Colors.success.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "flag.pattern.checkered.2.crossed")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.Colors.success)
                }

                Text("Round In Progress")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, Theme.Spacing.md)

                Text("You already have a round at \(currentCourseName). Resume it, or delete it and start a new round at \(nextCourseName).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, 6)

                HStack(spacing: Theme.Spacing.sm) {
                    Button(action: onResume) {
                        Text("Resume Round")
                            .font(Theme.Typography.title3)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.Colors.textPrimary.opacity(0.06))
                            )
                    }
                    .buttonStyle(ScorlyPressStyle())

                    Button(action: onDeleteAndStartNew) {
                        Text("Delete Round")
                            .font(Theme.Typography.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .fill(Theme.Colors.error)
                            )
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.Colors.surface)
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
                .padding(Theme.Spacing.pageHorizontal)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.Colors.canvas)
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
            .padding(.top, Theme.Spacing.md).padding(.trailing, Theme.Spacing.md)
            VStack(alignment: .leading, spacing: 5) {
                Text(course.name)
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    .minimumScaleFactor(0.75).lineLimit(2)
                Text(course.location)
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.70))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.xl).padding(.top, 60).padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
    }

    private var statRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            statCard(title: "Par",     value: "\(course.par)")
            statCard(title: "Yardage", value: "\(course.yardage)")
            statCard(title: "Holes",   value: "\(course.holes.count)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.Typography.captionSmall).foregroundStyle(Theme.Colors.textSecondary)
            Text(value).font(Theme.Typography.title).foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity).frame(height: 72).background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private var teeRatingsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("TEE").frame(maxWidth: .infinity, alignment: .leading)
                Text("RATING").frame(width: 72, alignment: .center)
                Text("SLOPE").frame(width: 64, alignment: .trailing)
            }
            .font(Theme.Typography.captionSmall).foregroundStyle(Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 11)
            Divider().padding(.horizontal, Theme.Spacing.md)
            ForEach(Array(course.tees.enumerated()), id: \.element.id) { index, tee in
                HStack(spacing: 0) {
                    Text(tee.name).frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f", tee.rating)).frame(width: 72, alignment: .center)
                    Text("\(tee.slope)").frame(width: 64, alignment: .trailing)
                }
                .font(Theme.Typography.body).foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 11)
                if index < course.tees.count - 1 { Divider().padding(.leading, Theme.Spacing.md) }
            }
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func scorecardCard(title: String, label: String, holes: [CourseHole]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased()).font(Theme.Typography.captionSmall).foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md).padding(.top, 14).padding(.bottom, 10)
            scorecardRow("HOLE", hcp: "HCP", t0: course.tees[0].name.prefix(4).uppercased(),
                         t1: course.tees[1].name.prefix(4).uppercased(),
                         t2: course.tees[2].name.prefix(3).uppercased(), par: "PAR", style: .header)
            Divider().padding(.horizontal, Theme.Spacing.md)
            ForEach(Array(holes.enumerated()), id: \.element.id) { index, hole in
                scorecardRow("\(hole.number)", hcp: "\(hole.handicap)",
                             t0: "\(hole.yardages[0])", t1: "\(hole.yardages[1])", t2: "\(hole.yardages[2])",
                             par: "\(hole.par)", style: .normal)
                if index < holes.count - 1 { Divider().padding(.leading, Theme.Spacing.md) }
            }
            Divider().padding(.horizontal, Theme.Spacing.md)
            scorecardRow(label, hcp: "",
                         t0: "\(ydsTotal(holes, 0))", t1: "\(ydsTotal(holes, 1))", t2: "\(ydsTotal(holes, 2))",
                         par: "\(parTotal(holes))", style: .subtotal)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
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
        .foregroundStyle(style == .header ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
        .background(style == .subtotal ? Theme.Colors.textPrimary.opacity(0.03) : Color.clear)
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
        .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 14)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }
}
