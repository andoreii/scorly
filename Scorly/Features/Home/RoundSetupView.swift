//
// RoundSetupView.swift
// Round setup screen — configure details before starting a round.
//

import SwiftUI

struct RoundSetupView: View {
    enum PresentationStyle {
        case sheet
        case embedded
    }

    struct StartPayload: Equatable {
        let datePlayed: Date
        let holesOption: HolesOption
        let teeIndex: Int
        let notes: String
        let conditions: [String]
        let temperature: Int?
        let roundType: String
        let roundFormat: String
        let transport: String
        let mentalState: Int
    }

    let course: Course
    var onStart: ((StartPayload) -> Void)? = nil
    var onPayloadChange: ((StartPayload) -> Void)? = nil
    var presentationStyle: PresentationStyle = .sheet
    var isVisible: Bool = true
    var showsHeader: Bool = true
    var showsCourseCard: Bool = true
    var showsStartButton: Bool = true
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var roundStore: RoundStore

    // Round fields
    @State private var date: Date = .now
    @State private var holesOption: HolesOption = .full18
    @State private var selectedTeeIndex: Int = 0
    @State private var selectedConditions: Set<Condition> = []
    @State private var temperature: String = ""
    @State private var roundType: RoundType = .casual
    @State private var roundFormat: RoundFormat = .strokePlay
    @State private var transport: Transport = .walking
    @State private var mentalState: Int = 5
    @State private var notes: String = ""

    // MARK: - Enums

    enum HolesOption: String, CaseIterable, Codable {
        case front9 = "Front 9"
        case back9  = "Back 9"
        case full18 = "Full 18"
    }

    enum RoundType: String, CaseIterable {
        case casual      = "Casual"
        case practice    = "Practice"
        case competitive = "Competitive"
        case tournament  = "Tournament"
    }

    enum RoundFormat: String, CaseIterable {
        case strokePlay  = "Stroke Play"
        case matchPlay   = "Match Play"
        case stableford  = "Stableford"
        case scramble    = "Scramble"
    }

    enum Transport: String, CaseIterable {
        case walking = "Walking"
        case riding  = "Riding"

        var icon: String {
            switch self {
            case .walking: return "figure.walk"
            case .riding:  return "car.fill"
            }
        }
    }

    enum Condition: String, CaseIterable, Hashable {
        case sunny   = "Sunny"
        case cloudy  = "Cloudy"
        case windy   = "Windy"
        case rainy   = "Rainy"

        var icon: String {
            switch self {
            case .sunny:  return "sun.max.fill"
            case .cloudy: return "cloud.fill"
            case .windy:  return "wind"
            case .rainy:  return "cloud.rain.fill"
            }
        }

        var color: Color {
            switch self {
            case .sunny:  return Theme.Colors.warning
            case .cloudy: return Color(red: 0.70, green: 0.74, blue: 0.80)
            case .windy:  return Theme.Colors.textTertiary
            case .rainy:  return Theme.Colors.water
            }
        }
    }

    private var selectedConditionNames: [String] {
        Condition.allCases
            .filter { selectedConditions.contains($0) }
            .map(\.rawValue)
    }
    private var parsedTemperature: Int? {
        Int(temperature.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var startPayload: StartPayload {
        StartPayload(
            datePlayed: date,
            holesOption: holesOption,
            teeIndex: selectedTeeIndex,
            notes: notes,
            conditions: selectedConditionNames,
            temperature: parsedTemperature,
            roundType: roundType.rawValue,
            roundFormat: roundFormat.rawValue,
            transport: transport.rawValue,
            mentalState: mentalState
        )
    }

    // MARK: - Body

    var body: some View {
        Group {
            if presentationStyle == .embedded {
                embeddedContent
            } else {
                sheetContent
            }
        }
        .onAppear {
            onPayloadChange?(startPayload)
        }
        .onChange(of: startPayload) { _, payload in
            onPayloadChange?(payload)
        }
    }

    private var sheetContent: some View {
        ZStack(alignment: .bottom) {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if showsHeader {
                        header
                            .padding(.horizontal, Theme.Spacing.pageHorizontal)
                    }

                    if showsCourseCard {
                        CourseCardView(course: course, isSelected: false)
                            .padding(.horizontal, Theme.Spacing.pageHorizontal)
                            .padding(.top, Theme.Spacing.sm)
                            .allowsHitTesting(false)
                    }

                    setupSections()
                        .padding(.horizontal, Theme.Spacing.pageHorizontal)
                        .padding(.top, Theme.Spacing.pageHorizontal)
                        .padding(.bottom, showsStartButton ? 100 : Theme.Spacing.huge)
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .scrollBounceBehavior(.basedOnSize)

            if showsStartButton {
                startButton
                    .padding(.horizontal, Theme.Spacing.pageHorizontal)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        Theme.Colors.canvas
                            .shadow(color: Theme.Colors.textPrimary.opacity(0.07), radius: 16, y: -4)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
        }
    }

    private var embeddedContent: some View {
        setupSections()
            .background(Color.clear)
    }

    private func setupSections(startIndex: Int = 0) -> some View {
        VStack(spacing: Theme.Spacing.xs + 2) {
            dateSection(sectionIndex: startIndex)
            gameCard(sectionIndex: startIndex + 1)
            courseCard(sectionIndex: startIndex + 2)
            environmentCard(sectionIndex: startIndex + 3)
            mentalStateSection(sectionIndex: startIndex + 4)
            notesSection(sectionIndex: startIndex + 5)
        }
    }

    // MARK: - Background

    private var background: some View {
        Theme.Colors.canvas
            .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(Theme.Colors.textPrimary.opacity(0.05), in: Circle())
            }
            .buttonStyle(ScorlyPressStyle())

            Spacer()

            Text("Round Setup")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .frame(height: 44)
    }

    // MARK: - Date

    private func dateSection(sectionIndex: Int) -> some View {
        formCard {
            HStack {
                sectionLabel(icon: "calendar", title: "Date")
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(Theme.Colors.accent)
            }
        }
        .sequencedVisibility(
            index: sectionIndex,
            isVisible: isVisible,
            hiddenOffset: 26,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    // MARK: - Game (Type + Format combined)

    private func gameCard(sectionIndex: Int) -> some View {
        formCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    sectionLabel(icon: "flag.checkered", title: "Type")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xxs + 2) {
                        ForEach(RoundType.allCases, id: \.self) { type in
                            Button(action: { roundType = type }) {
                                Text(type.rawValue)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(roundType == type ? .white : Theme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                            .fill(roundType == type ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: roundType)
                        }
                    }
                }

                ScorlyDivider()

                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    sectionLabel(icon: "list.bullet.clipboard", title: "Format")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xxs + 2) {
                        ForEach(RoundFormat.allCases, id: \.self) { format in
                            Button(action: { roundFormat = format }) {
                                Text(format.rawValue)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(roundFormat == format ? .white : Theme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                            .fill(roundFormat == format ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: roundFormat)
                        }
                    }
                }
            }
        }
        .sequencedVisibility(
            index: sectionIndex,
            isVisible: isVisible,
            hiddenOffset: 26,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    // MARK: - Course (Holes + Tee combined)

    private func courseCard(sectionIndex: Int) -> some View {
        formCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    sectionLabel(icon: "flag.fill", title: "Holes")
                    HStack(spacing: Theme.Spacing.xxs + 2) {
                        ForEach(HolesOption.allCases, id: \.self) { option in
                            Button(action: { holesOption = option }) {
                                Text(option.rawValue)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(holesOption == option ? .white : Theme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                            .fill(holesOption == option ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: holesOption)
                        }
                    }
                }

                ScorlyDivider()

                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    sectionLabel(icon: "circle.fill", title: "Tee")
                    HStack(spacing: Theme.Spacing.xxs + 2) {
                        ForEach(Array(course.tees.enumerated()), id: \.offset) { index, tee in
                            Button(action: { selectedTeeIndex = index }) {
                                VStack(spacing: 1) {
                                    Text(tee.name)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(selectedTeeIndex == index ? .white : Theme.Colors.textPrimary)
                                    Text(String(format: "%.1f / %d", tee.rating, tee.slope))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selectedTeeIndex == index ? .white.opacity(0.70) : Theme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                        .fill(selectedTeeIndex == index ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.05))
                                )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: selectedTeeIndex)
                        }
                    }
                }
            }
        }
        .sequencedVisibility(
            index: sectionIndex,
            isVisible: isVisible,
            hiddenOffset: 26,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    // MARK: - Environment (Transport + Conditions + Temperature combined)

    private func environmentCard(sectionIndex: Int) -> some View {
        formCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    sectionLabel(icon: "figure.walk", title: "Transport")
                    HStack(spacing: Theme.Spacing.xxs + 2) {
                        ForEach(Transport.allCases, id: \.self) { option in
                            Button(action: { transport = option }) {
                                HStack(spacing: 5) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(option.rawValue)
                                        .font(Theme.Typography.caption)
                                }
                                .foregroundStyle(transport == option ? .white : Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                        .fill(transport == option ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.05))
                                )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: transport)
                        }
                    }
                }

                ScorlyDivider()

                VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
                    sectionLabel(icon: "cloud.sun.fill", title: "Conditions")
                    HStack(spacing: Theme.Spacing.xxs + 2) {
                        ForEach(Condition.allCases, id: \.self) { c in
                            let selected = selectedConditions.contains(c)
                            Button(action: {
                                if selected {
                                    selectedConditions.remove(c)
                                } else {
                                    selectedConditions.insert(c)
                                }
                            }) {
                                VStack(spacing: Theme.Spacing.xxs) {
                                    Image(systemName: c.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(selected ? c.color : Theme.Colors.textTertiary)
                                    Text(c.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selected ? Theme.Colors.textPrimary : Theme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: Theme.Spacing.huge)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                        .fill(selected ? Theme.Colors.textPrimary.opacity(0.05) : Theme.Colors.textPrimary.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                        .strokeBorder(selected ? Theme.Colors.whisperBorder : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(ScorlyPressStyle())
                            .animation(Theme.Animation.snappy, value: selected)
                        }
                    }
                }

                ScorlyDivider()

                HStack {
                    sectionLabel(icon: "thermometer.medium", title: "Temperature")
                    Spacer()
                    HStack(spacing: Theme.Spacing.xxxs) {
                        TextField("--", text: $temperature)
                            .keyboardType(.numberPad)
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 46)
                        Text("°")
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
            }
        }
        .sequencedVisibility(
            index: sectionIndex,
            isVisible: isVisible,
            hiddenOffset: 26,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    // MARK: - Mental State

    private func mentalStateSection(sectionIndex: Int) -> some View {
        formCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm + 2) {
                HStack {
                    sectionLabel(icon: "brain.head.profile", title: "Mental State")
                    Spacer()
                    Text("\(mentalState) / 10")
                        .font(Theme.Typography.bodySemibold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()
                }
                HStack(spacing: Theme.Spacing.xxs + 2) {
                    ForEach(1...10, id: \.self) { value in
                        Button(action: { mentalState = value }) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(value <= mentalState ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.08))
                                .frame(height: 28)
                        }
                        .buttonStyle(ScorlyPressStyle())
                        .animation(Theme.Animation.snappy, value: mentalState)
                    }
                }
            }
        }
        .sequencedVisibility(
            index: sectionIndex,
            isVisible: isVisible,
            hiddenOffset: 26,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    // MARK: - Notes

    private func notesSection(sectionIndex: Int) -> some View {
        formCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm + 2) {
                sectionLabel(icon: "note.text", title: "Notes")
                TextField("Optional", text: $notes, axis: .vertical)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(3...6)
            }
        }
        .sequencedVisibility(
            index: sectionIndex,
            isVisible: isVisible,
            hiddenOffset: 26,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    // MARK: - Start button

    private var startButton: some View {
        Button(action: {
            if let onStart {
                onStart(startPayload)
            } else {
                dismiss()
            }
        }) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Start Round")
                    .font(Theme.Typography.title3)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.huge)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Colors.accent)
            )
            .themeShadow(Theme.Shadow.glow)
        }
        .buttonStyle(ScorlyPressStyle())
    }

    // MARK: - Helpers

    private func formCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
            )
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
