//
// EditCourseSheet.swift
// Pre-filled form sheet for editing an existing course.
//

import SwiftUI

struct EditCourseSheet: View {
    let course: Course
    var onSave: (Course) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var location: String
    @State private var selectedTheme: Int
    @State private var tees: [TeeInput]
    @State private var holeInputs: [HoleInput]
    @State private var expandedHole: Int? = nil
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    init(course: Course, onSave: @escaping (Course) -> Void) {
        self.course = course
        self.onSave = onSave
        _name     = State(initialValue: course.name)
        _location = State(initialValue: course.location)

        // Match accent colors to a theme index (default to 0 if no match)
        let themeIdx = AddCourseSheet.themes.firstIndex { theme in
            guard theme.colors.count >= 2, course.accentColors.count >= 2 else { return false }
            return colorApproxEqual(theme.colors[0], course.accentColors[0]) &&
                   colorApproxEqual(theme.colors[1], course.accentColors[1])
        } ?? 0
        _selectedTheme = State(initialValue: themeIdx)

        _tees = State(initialValue: course.tees.map {
            TeeInput(databaseId: $0.databaseId,
                     name: $0.name,
                     rating: String(format: "%.1f", $0.rating),
                     slope: "\($0.slope)")
        })

        _holeInputs = State(initialValue: course.holes.map { hole in
            HoleInput(
                number: hole.number,
                par: hole.par,
                handicap: hole.handicap,
                yardages: hole.yardages.map { "\($0)" }
            )
        })
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tees.isEmpty &&
        tees.allSatisfy(isValidTee) &&
        holeInputs.allSatisfy(isValidHole)
    }

    private var totalPar: Int { holeInputs.reduce(0) { $0 + $1.par } }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    saveErrorMessage = nil
                }
            }
        )
    }

    private func isValidTee(_ tee: TeeInput) -> Bool {
        !tee.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(tee.rating) != nil &&
        Int(tee.slope) != nil
    }

    private func isValidHole(_ hole: HoleInput) -> Bool {
        (3...5).contains(hole.par) &&
        (1...18).contains(hole.handicap) &&
        hole.yardages.count >= tees.count &&
        hole.yardages.prefix(tees.count).allSatisfy { yardage in
            guard let value = Int(yardage) else { return false }
            return (50...800).contains(value)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sheetHeader

                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("COLOR THEME")
                    themeGrid

                    sectionLabel("COURSE INFO")
                    infoCard

                    sectionLabel("TEES")
                    teesSection

                    sectionLabel("SCORECARD")
                    scorecardSection

                    Button(action: save) {
                        Text(isSaving ? "Saving..." : "Save Changes")
                            .font(Theme.Typography.title3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                    .fill(canSave ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.28))
                            )
                    }
                    .disabled(!canSave || isSaving)
                    .buttonStyle(ScorlyPressStyle())
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.huge)
                }
                .padding(.horizontal, Theme.Spacing.pageHorizontal)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.canvas)
        .alert("Unable to Save Course", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Please check the course details and try again.")
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: AddCourseSheet.themes[selectedTheme].colors,
                startPoint: .leading,
                endPoint: .trailing
            )
            .overlay(LinearGradient(colors: [.white.opacity(0.12), .clear],
                                    startPoint: .topLeading, endPoint: .center))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.22), in: Circle())
            }
            .buttonStyle(ScorlyPressStyle())
            .padding(.top, Theme.Spacing.md).padding(.trailing, Theme.Spacing.pageHorizontal)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(name.isEmpty ? "Course Name" : name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(name.isEmpty ? .white.opacity(0.35) : .white)
                    .lineLimit(2)
                Text(location.isEmpty ? "Location" : location)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white.opacity(location.isEmpty ? 0.35 : 0.70))
                Text("Par \(totalPar)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, Theme.Spacing.xxxs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.pageHorizontal)
            .padding(.top, 60)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Theme grid

    private var themeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.xs + 2), count: 3), spacing: Theme.Spacing.xs + 2) {
            ForEach(AddCourseSheet.themes.indices, id: \.self) { i in
                let theme = AddCourseSheet.themes[i]
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous)
                        .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 56)
                    if selectedTheme == i {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(Theme.Spacing.xxs + 2)
                    }
                    Text(theme.name)
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, Theme.Spacing.xs)
                        .padding(.bottom, Theme.Spacing.xxs + 2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous)
                        .strokeBorder(selectedTheme == i ? .white : .clear, lineWidth: 2)
                )
                .onTapGesture { withAnimation(Theme.Animation.snappy) { selectedTheme = i } }
            }
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - Course info

    private var infoCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 80, alignment: .leading)
                TextField("e.g. Pebble Beach G.L.", text: $name)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)

            Divider().padding(.horizontal, Theme.Spacing.md)

            HStack {
                Text("Location")
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 80, alignment: .leading)
                TextField("e.g. Pebble Beach, CA", text: $location)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 2)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: - Tees

    private var teesSection: some View {
        VStack(spacing: Theme.Spacing.xs + 2) {
            ForEach(tees.indices, id: \.self) { i in
                teeRow(index: i)
            }

            HStack {
                Button {
                    withAnimation(Theme.Animation.smooth) {
                        tees.append(TeeInput(name: "", rating: "", slope: ""))
                        for j in holeInputs.indices {
                            while holeInputs[j].yardages.count < tees.count {
                                holeInputs[j].yardages.append("")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(Theme.Typography.caption)
                        Text("Add Tee")
                            .font(Theme.Typography.caption)
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(ScorlyPressStyle())

                Spacer()

                if tees.count > 1 {
                    Button {
                        withAnimation(Theme.Animation.smooth) {
                            tees.removeLast()
                            for j in holeInputs.indices {
                                while holeInputs[j].yardages.count > tees.count {
                                    holeInputs[j].yardages.removeLast()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "minus.circle.fill")
                                .font(Theme.Typography.caption)
                            Text("Remove")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.error.opacity(0.80))
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
            }
            .padding(.top, Theme.Spacing.xxs)
        }
        .padding(.bottom, Theme.Spacing.xl)
    }

    private func teeRow(index i: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 60, alignment: .leading)
                TextField("e.g. Championship", text: $tees[i].name)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.sm + 2).padding(.vertical, Theme.Spacing.sm - 1)
            Divider().padding(.horizontal, Theme.Spacing.sm + 2)
            HStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Rating")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 60, alignment: .leading)
                    TextField("72.0", text: $tees[i].rating)
                        .font(.system(size: 14)).foregroundStyle(Theme.Colors.textPrimary)
                        .keyboardType(.decimalPad)
                }
                Divider().frame(height: Theme.Spacing.pageHorizontal)
                HStack {
                    Text("Slope")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 48, alignment: .leading)
                    TextField("113", text: $tees[i].slope)
                        .font(.system(size: 14)).foregroundStyle(Theme.Colors.textPrimary)
                        .keyboardType(.numberPad)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm + 2).padding(.vertical, Theme.Spacing.sm - 1)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    // MARK: - Scorecard

    private var scorecardSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 30, alignment: .leading)
                Text("Par")
                    .frame(width: 34, alignment: .center)
                Text("HCP")
                    .frame(width: 34, alignment: .center)
                ForEach(0..<tees.count, id: \.self) { t in
                    Text(tees[t].name.isEmpty ? "Tee \(t+1)" : String(tees[t].name.prefix(4)))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                }
            }
            .font(Theme.Typography.captionSmall)
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Theme.Colors.surface)

            Divider().padding(.horizontal, Theme.Spacing.sm)

            ForEach(holeInputs.indices, id: \.self) { idx in
                holeCollapsedRow(idx: idx)
                if idx < holeInputs.count - 1 {
                    Divider().padding(.horizontal, Theme.Spacing.sm).opacity(0.5)
                }
                if expandedHole == idx {
                    holeEditor(idx: idx)
                    if idx < holeInputs.count - 1 {
                        Divider().padding(.horizontal, Theme.Spacing.sm)
                    }
                }
                if idx == 8 {
                    Divider().padding(.horizontal, Theme.Spacing.sm)
                    subtotalRow(label: "OUT", range: 0..<9)
                    Divider().padding(.horizontal, Theme.Spacing.sm)
                }
            }

            Divider().padding(.horizontal, Theme.Spacing.sm)
            subtotalRow(label: "IN", range: 9..<18)
            Divider().padding(.horizontal, Theme.Spacing.sm)
            subtotalRow(label: "TOTAL", range: 0..<18)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
        .padding(.bottom, Theme.Spacing.xl)
    }

    private func holeCollapsedRow(idx: Int) -> some View {
        let hole = holeInputs[idx]
        let isExpanded = expandedHole == idx

        return HStack(spacing: 0) {
            Text("\(hole.number)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 30, alignment: .leading)
            Text("\(hole.par)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 34, alignment: .center)
            Text("\(hole.handicap)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 34, alignment: .center)
            ForEach(0..<tees.count, id: \.self) { t in
                let raw = t < hole.yardages.count ? hole.yardages[t] : ""
                let yds = Int(raw) ?? 0
                Text(yds > 0 ? "\(yds)" : "—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(yds > 0 ? Theme.Colors.textSecondary : Theme.Colors.textTertiary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 20)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Theme.Animation.smooth) {
                expandedHole = isExpanded ? nil : idx
            }
        }
    }

    private func holeEditor(idx: Int) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Par picker
            HStack {
                Text("Par")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach([3, 4, 5], id: \.self) { p in
                        Button {
                            holeInputs[idx].par = p
                        } label: {
                            Text("\(p)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(holeInputs[idx].par == p ? .white : Theme.Colors.textPrimary)
                                .frame(width: 38, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                        .fill(holeInputs[idx].par == p ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.06))
                                )
                        }
                        .buttonStyle(ScorlyPressStyle())
                        .animation(Theme.Animation.snappy, value: holeInputs[idx].par)
                    }
                }
            }

            // Handicap stepper
            HStack {
                Text("Handicap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        if holeInputs[idx].handicap > 1 { holeInputs[idx].handicap -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.textPrimary.opacity(0.06)))
                    }
                    .buttonStyle(ScorlyPressStyle())

                    Text("\(holeInputs[idx].handicap)")
                        .font(Theme.Typography.bodySemibold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .monospacedDigit()
                        .frame(minWidth: Theme.Spacing.xl, alignment: .center)
                        .contentTransition(.numericText(value: Double(holeInputs[idx].handicap)))
                        .animation(Theme.Animation.snappy, value: holeInputs[idx].handicap)

                    Button {
                        if holeInputs[idx].handicap < 18 { holeInputs[idx].handicap += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.textPrimary.opacity(0.06)))
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
            }

            // Yardages per tee
            ForEach(0..<tees.count, id: \.self) { t in
                HStack {
                    Text(tees[t].name.isEmpty ? "Tee \(t+1)" : tees[t].name)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    TextField("yds", text: yardageBinding(hole: idx, tee: t))
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.textPrimary.opacity(0.02))
    }

    private func subtotalRow(label: String, range: Range<Int>) -> some View {
        let parSum = holeInputs[range].reduce(0) { $0 + $1.par }
        return HStack(spacing: 0) {
            Text(label)
                .frame(width: 30, alignment: .leading)
            Text("\(parSum)")
                .frame(width: 34, alignment: .center)
            Text("")
                .frame(width: 34, alignment: .center)
            ForEach(0..<tees.count, id: \.self) { t in
                let total = holeInputs[range].reduce(0) { sum, h in
                    let yds = t < h.yardages.count ? (Int(h.yardages[t]) ?? 0) : 0
                    return sum + yds
                }
                Text(total > 0 ? "\(total)" : "—")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.textPrimary)
        .monospacedDigit()
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(Theme.Colors.textPrimary.opacity(0.03))
    }

    private func yardageBinding(hole: Int, tee: Int) -> Binding<String> {
        Binding(
            get: {
                tee < holeInputs[hole].yardages.count ? holeInputs[hole].yardages[tee] : ""
            },
            set: { newValue in
                while holeInputs[hole].yardages.count <= tee {
                    holeInputs[hole].yardages.append("")
                }
                holeInputs[hole].yardages[tee] = newValue
            }
        )
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.captionSmall)
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.top, 28)
            .padding(.bottom, Theme.Spacing.xs + 2)
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let courseId = course.databaseId, !trimmedName.isEmpty, canSave else { return }

        isSaving = true

        let teePayload = tees.compactMap { tee -> (databaseId: Int?, name: String, rating: Double?, slope: Double?, yardage: Int?)? in
            guard
                let rating = Double(tee.rating),
                let slope = Double(tee.slope)
            else { return nil }

            guard let teeIndex = tees.firstIndex(where: { $0.id == tee.id }) else { return nil }

            let yardages = holeInputs.compactMap { hole -> Int? in
                guard teeIndex < hole.yardages.count else { return nil }
                return Int(hole.yardages[teeIndex])
            }

            return (
                databaseId: tee.databaseId,
                name: tee.name.trimmingCharacters(in: .whitespacesAndNewlines),
                rating: rating,
                slope: slope,
                yardage: yardages.reduce(0, +)
            )
        }

        let holePayload = holeInputs.map { hole in
            (number: hole.number, par: hole.par, handicap: Optional(hole.handicap))
        }

        let teeHoleYardages = tees.indices.map { teeIndex in
            holeInputs.map { hole in
                Int(hole.yardages[teeIndex]) ?? 0
            }
        }

        Task {
            do {
                let savedRow = try await DataService.shared.updateCourse(
                    courseId: courseId,
                    name: trimmedName,
                    location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                    notes: nil,
                    colorTheme: AddCourseSheet.themes[selectedTheme].name,
                    tees: teePayload,
                    holes: holePayload,
                    teeHoleYardages: teeHoleYardages
                )

                await MainActor.run {
                    isSaving = false
                    onSave(Course(from: savedRow))
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Color comparison helper

private func colorApproxEqual(_ a: Color, _ b: Color) -> Bool {
    let ua = UIColor(a), ub = UIColor(b)
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    return abs(r1 - r2) < 0.05 && abs(g1 - g2) < 0.05 && abs(b1 - b2) < 0.05
}
