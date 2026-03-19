//
// RoundSetupView.swift
// Round setup screen — configure details before starting a round.
//

import SwiftUI

struct RoundSetupView: View {
    struct StartPayload {
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
            case .sunny:  return Color(red: 0.99, green: 0.76, blue: 0.18)
            case .cloudy: return Color(red: 0.70, green: 0.74, blue: 0.80)
            case .windy:  return Color(red: 0.55, green: 0.76, blue: 0.95)
            case .rainy:  return Color(red: 0.36, green: 0.57, blue: 0.90)
            }
        }
    }

    private let cardCornerRadius: CGFloat = 13
    private var selectedConditionNames: [String] {
        Condition.allCases
            .filter { selectedConditions.contains($0) }
            .map(\.rawValue)
    }
    private var parsedTemperature: Int? {
        Int(temperature.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)

                    CourseCardView(course: course, isSelected: false)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .allowsHitTesting(false)

                    VStack(spacing: 10) {
                        dateSection
                        gameCard
                        courseCard
                        environmentCard
                        mentalStateSection
                        notesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100) // clear space for the fixed button
                }
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            // Fixed bottom button
            startButton
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Color(red: 0.97, green: 0.97, blue: 0.98)
                        .shadow(color: .black.opacity(0.07), radius: 16, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
    }

    // MARK: - Background

    private var background: some View {
        Color(red: 0.97, green: 0.97, blue: 0.98)
            .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.50))
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Round Setup")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)

            Spacer()

            Color.clear.frame(width: 34, height: 34)
        }
        .frame(height: 44)
    }

    // MARK: - Date

    private var dateSection: some View {
        formCard {
            HStack {
                sectionLabel(icon: "calendar", title: "Date")
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.black)
            }
        }
    }

    // MARK: - Game (Type + Format combined)

    private var gameCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(icon: "flag.checkered", title: "Type")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(RoundType.allCases, id: \.self) { type in
                            Button(action: { roundType = type }) {
                                Text(type.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(roundType == type ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(roundType == type ? Color.black : Color.black.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: roundType)
                        }
                    }
                }

                Rectangle().fill(.black.opacity(0.06)).frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(icon: "list.bullet.clipboard", title: "Format")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(RoundFormat.allCases, id: \.self) { format in
                            Button(action: { roundFormat = format }) {
                                Text(format.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(roundFormat == format ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(roundFormat == format ? Color.black : Color.black.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: roundFormat)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Course (Holes + Tee combined)

    private var courseCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(icon: "flag.fill", title: "Holes")
                    HStack(spacing: 6) {
                        ForEach(HolesOption.allCases, id: \.self) { option in
                            Button(action: { holesOption = option }) {
                                Text(option.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(holesOption == option ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(holesOption == option ? Color.black : Color.black.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: holesOption)
                        }
                    }
                }

                Rectangle().fill(.black.opacity(0.06)).frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(icon: "circle.fill", title: "Tee")
                    HStack(spacing: 6) {
                        ForEach(Array(course.tees.enumerated()), id: \.offset) { index, tee in
                            Button(action: { selectedTeeIndex = index }) {
                                VStack(spacing: 1) {
                                    Text(tee.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(selectedTeeIndex == index ? .white : .black)
                                    Text(String(format: "%.1f / %d", tee.rating, tee.slope))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selectedTeeIndex == index ? .white.opacity(0.70) : .black.opacity(0.40))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedTeeIndex == index ? Color.black : Color.black.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: selectedTeeIndex)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Environment (Transport + Conditions + Temperature combined)

    private var environmentCard: some View {
        formCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(icon: "figure.walk", title: "Transport")
                    HStack(spacing: 6) {
                        ForEach(Transport.allCases, id: \.self) { option in
                            Button(action: { transport = option }) {
                                HStack(spacing: 5) {
                                    Image(systemName: option.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(option.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(transport == option ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(transport == option ? Color.black : Color.black.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: transport)
                        }
                    }
                }

                Rectangle().fill(.black.opacity(0.06)).frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(icon: "cloud.sun.fill", title: "Conditions")
                    HStack(spacing: 6) {
                        ForEach(Condition.allCases, id: \.self) { c in
                            let selected = selectedConditions.contains(c)
                            Button(action: {
                                if selected {
                                    selectedConditions.remove(c)
                                } else {
                                    selectedConditions.insert(c)
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: c.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(selected ? c.color : .black.opacity(0.30))
                                    Text(c.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selected ? .black : .black.opacity(0.35))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selected ? Color.black.opacity(0.05) : Color.black.opacity(0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(selected ? Color.black.opacity(0.15) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.16), value: selected)
                        }
                    }
                }

                Rectangle().fill(.black.opacity(0.06)).frame(height: 1)

                HStack {
                    sectionLabel(icon: "thermometer.medium", title: "Temperature")
                    Spacer()
                    HStack(spacing: 2) {
                        TextField("--", text: $temperature)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 46)
                        Text("°")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                }
            }
        }
    }

    // MARK: - Mental State

    private var mentalStateSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    sectionLabel(icon: "brain.head.profile", title: "Mental State")
                    Spacer()
                    Text("\(mentalState) / 10")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                }
                HStack(spacing: 6) {
                    ForEach(1...10, id: \.self) { value in
                        Button(action: { mentalState = value }) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(value <= mentalState ? Color.black : Color.black.opacity(0.08))
                                .frame(height: 28)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.12), value: mentalState)
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel(icon: "note.text", title: "Notes")
                TextField("Optional", text: $notes, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.black)
                    .lineLimit(3...6)
            }
        }
    }

    // MARK: - Start button

    private var startButton: some View {
        Button(action: {
            if let onStart {
                onStart(
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
                )
            } else {
                dismiss()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Start Round")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.22, green: 0.22, blue: 0.24), Color.black],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .shadow(color: Color.black.opacity(0.30), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 8, y: 3)
    }

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black.opacity(0.4))
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
        }
    }
}
