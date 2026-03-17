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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(canSave ? Color.black : Color.black.opacity(0.28))
                            )
                    }
                    .disabled(!canSave || isSaving)
                    .buttonStyle(.plain)
                    .padding(.top, 32)
                    .padding(.bottom, 48)
                }
                .padding(.horizontal, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .background(Color(red: 0.97, green: 0.97, blue: 0.98))
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
            .buttonStyle(.plain)
            .padding(.top, 16).padding(.trailing, 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Course Name" : name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(name.isEmpty ? .white.opacity(0.35) : .white)
                    .lineLimit(2)
                Text(location.isEmpty ? "Location" : location)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(location.isEmpty ? 0.35 : 0.70))
                Text("Par \(totalPar)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Theme grid

    private var themeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(AddCourseSheet.themes.indices, id: \.self) { i in
                let theme = AddCourseSheet.themes[i]
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(height: 56)
                    if selectedTheme == i {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                    Text(theme.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selectedTheme == i ? .white : .clear, lineWidth: 2)
                )
                .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selectedTheme = i } }
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Course info

    private var infoCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.55))
                    .frame(width: 80, alignment: .leading)
                TextField("e.g. Pebble Beach G.L.", text: $name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            HStack {
                Text("Location")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black.opacity(0.55))
                    .frame(width: 80, alignment: .leading)
                TextField("e.g. Pebble Beach, CA", text: $location)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        .padding(.bottom, 24)
    }

    // MARK: - Tees

    private var teesSection: some View {
        VStack(spacing: 10) {
            ForEach(tees.indices, id: \.self) { i in
                teeRow(index: i)
            }

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
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
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add Tee")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.black.opacity(0.55))
                }
                .buttonStyle(.plain)

                Spacer()

                if tees.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
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
                                .font(.system(size: 13, weight: .semibold))
                            Text("Remove")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Color(red: 0.80, green: 0.18, blue: 0.14).opacity(0.80))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 24)
    }

    private func teeRow(index i: Int) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.50))
                    .frame(width: 60, alignment: .leading)
                TextField("e.g. Championship", text: $tees[i].name)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            Divider().padding(.horizontal, 14)
            HStack(spacing: 16) {
                HStack {
                    Text("Rating")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.50))
                        .frame(width: 60, alignment: .leading)
                    TextField("72.0", text: $tees[i].rating)
                        .font(.system(size: 14)).foregroundStyle(.black)
                        .keyboardType(.decimalPad)
                }
                Divider().frame(height: 20)
                HStack {
                    Text("Slope")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.50))
                        .frame(width: 48, alignment: .leading)
                    TextField("113", text: $tees[i].slope)
                        .font(.system(size: 14)).foregroundStyle(.black)
                        .keyboardType(.numberPad)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black.opacity(0.40))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)

            Divider().padding(.horizontal, 12)

            ForEach(holeInputs.indices, id: \.self) { idx in
                holeCollapsedRow(idx: idx)
                if idx < holeInputs.count - 1 {
                    Divider().padding(.horizontal, 12).opacity(0.5)
                }
                if expandedHole == idx {
                    holeEditor(idx: idx)
                    if idx < holeInputs.count - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
                if idx == 8 {
                    Divider().padding(.horizontal, 12)
                    subtotalRow(label: "OUT", range: 0..<9)
                    Divider().padding(.horizontal, 12)
                }
            }

            Divider().padding(.horizontal, 12)
            subtotalRow(label: "IN", range: 9..<18)
            Divider().padding(.horizontal, 12)
            subtotalRow(label: "TOTAL", range: 0..<18)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        .padding(.bottom, 24)
    }

    private func holeCollapsedRow(idx: Int) -> some View {
        let hole = holeInputs[idx]
        let isExpanded = expandedHole == idx

        return HStack(spacing: 0) {
            Text("\(hole.number)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 30, alignment: .leading)
            Text("\(hole.par)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))
                .frame(width: 34, alignment: .center)
            Text("\(hole.handicap)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.45))
                .frame(width: 34, alignment: .center)
            ForEach(0..<tees.count, id: \.self) { t in
                let raw = t < hole.yardages.count ? hole.yardages[t] : ""
                let yds = Int(raw) ?? 0
                Text(yds > 0 ? "\(yds)" : "—")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(yds > 0 ? .black.opacity(0.65) : .black.opacity(0.20))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.black.opacity(0.30))
                .frame(width: 20)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedHole = isExpanded ? nil : idx
            }
        }
    }

    private func holeEditor(idx: Int) -> some View {
        VStack(spacing: 12) {
            // Par picker
            HStack {
                Text("Par")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                Spacer()
                HStack(spacing: 8) {
                    ForEach([3, 4, 5], id: \.self) { p in
                        Button {
                            holeInputs[idx].par = p
                        } label: {
                            Text("\(p)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(holeInputs[idx].par == p ? .white : .black)
                                .frame(width: 38, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(holeInputs[idx].par == p ? Color.black : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.12), value: holeInputs[idx].par)
                    }
                }
            }

            // Handicap stepper
            HStack {
                Text("Handicap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        if holeInputs[idx].handicap > 1 { holeInputs[idx].handicap -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)

                    Text("\(holeInputs[idx].handicap)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                        .frame(minWidth: 24, alignment: .center)

                    Button {
                        if holeInputs[idx].handicap < 18 { holeInputs[idx].handicap += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Yardages per tee
            ForEach(0..<tees.count, id: \.self) { t in
                HStack {
                    Text(tees[t].name.isEmpty ? "Tee \(t+1)" : tees[t].name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.55))
                        .lineLimit(1)
                    Spacer()
                    TextField("yds", text: yardageBinding(hole: idx, tee: t))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.02))
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
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.03))
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
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black.opacity(0.40))
            .padding(.top, 28)
            .padding(.bottom, 10)
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
