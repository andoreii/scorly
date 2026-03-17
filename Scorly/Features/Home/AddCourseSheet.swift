//
// AddCourseSheet.swift
// Form sheet for creating a new course.
//

import SwiftUI

struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Course) -> Void

    // Course info
    @State private var name     = ""
    @State private var location = ""

    // Theme
    @State private var selectedTheme = 0

    // Tees — dynamic list
    @State private var tees: [TeeInput] = [
        TeeInput(name: "", rating: "", slope: ""),
    ]

    // Holes — 18 holes with per-hole data
    @State private var holeInputs: [HoleInput] = (1...18).map { HoleInput(number: $0, yardages: [""]) }

    // Expanded hole for editing (nil = all collapsed)
    @State private var expandedHole: Int? = nil
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    static let themes: [(name: String, colors: [Color])] = [
        ("Forest",   [Color(red: 0.03, green: 0.25, blue: 0.09), Color(red: 0.30, green: 0.68, blue: 0.22)]),
        ("Ocean",    [Color(red: 0.14, green: 0.35, blue: 0.72), Color(red: 0.48, green: 0.82, blue: 0.90)]),
        ("Dusk",     [Color(red: 0.40, green: 0.08, blue: 0.12), Color(red: 0.88, green: 0.33, blue: 0.34)]),
        ("Desert",   [Color(red: 0.55, green: 0.30, blue: 0.08), Color(red: 0.92, green: 0.65, blue: 0.28)]),
        ("Twilight", [Color(red: 0.38, green: 0.32, blue: 0.64), Color(red: 0.84, green: 0.78, blue: 0.96)]),
        ("Slate",    [Color(red: 0.14, green: 0.16, blue: 0.20), Color(red: 0.42, green: 0.46, blue: 0.54)]),
        ("Ember",    [Color(red: 0.72, green: 0.18, blue: 0.08), Color(red: 0.96, green: 0.42, blue: 0.18)]),
        ("Mint",     [Color(red: 0.08, green: 0.48, blue: 0.42), Color(red: 0.32, green: 0.82, blue: 0.72)]),
        ("Noir",     [Color(red: 0.08, green: 0.08, blue: 0.10), Color(red: 0.28, green: 0.28, blue: 0.32)]),
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tees.isEmpty &&
        tees.allSatisfy(isValidTee) &&
        holeInputs.allSatisfy(isValidHole)
    }

    private var totalPar: Int {
        holeInputs.reduce(0) { $0 + $1.par }
    }

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

                    // Save button (inline)
                    Button(action: save) {
                        Text(isSaving ? "Saving..." : "Add Course")
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

    // MARK: - Header (live preview)

    private var sheetHeader: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: Self.themes[selectedTheme].colors,
                startPoint: .leading, endPoint: .trailing
            )
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear],
                    startPoint: .topLeading, endPoint: .center
                )
            )

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.22), in: Circle())
            }
            .padding(.top, 56).padding(.trailing, 16)

            VStack(alignment: .leading, spacing: 5) {
                Text(name.isEmpty ? "New Course" : name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    if !location.isEmpty {
                        Text(location)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    } else {
                        Text("Add location")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    Spacer()
                    Text(totalPar > 0 ? "Par \(totalPar)" : "Par —")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.70))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 80)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.22), value: selectedTheme)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black.opacity(0.32))
            .kerning(1.0)
            .padding(.top, 26)
            .padding(.bottom, 8)
    }

    // MARK: - Color theme grid

    private var themeGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<Self.themes.count, id: \.self) { i in
                let theme = Self.themes[i]
                let isSelected = selectedTheme == i
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        selectedTheme = i
                    }
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: theme.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(theme.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 8).padding(.bottom, 7)
                    }
                    .frame(height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Color.black.opacity(0.20) : Color.clear, lineWidth: 1)
                    )
                    .scaleEffect(isSelected ? 1.0 : 0.96)
                    .shadow(color: isSelected ? .black.opacity(0.18) : .black.opacity(0.06), radius: isSelected ? 8 : 4, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(spacing: 0) {
            formRow(label: "Name") {
                TextField("e.g. Pebble Beach", text: $name)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.trailing)
            }
            Divider().padding(.leading, 16)
            formRow(label: "Location") {
                TextField("City, State", text: $location)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.trailing)
            }
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black)
            Spacer()
            content()
                .foregroundStyle(.black.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Tees section

    private var teesSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("TEE").frame(maxWidth: .infinity, alignment: .leading)
                Text("RATING").frame(width: 62, alignment: .center)
                Text("SLOPE").frame(width: 50, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.black.opacity(0.35))
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().padding(.horizontal, 16)

            // Tee rows
            ForEach($tees) { $tee in
                HStack(spacing: 0) {
                    TextField("Tee name", text: $tee.name)
                        .font(.system(size: 15))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("72.0", text: $tee.rating)
                        .font(.system(size: 15))
                        .foregroundStyle(.black.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .frame(width: 62)
                    TextField("125", text: $tee.slope)
                        .font(.system(size: 15))
                        .foregroundStyle(.black.opacity(0.65))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                if tee.id != tees.last?.id {
                    Divider().padding(.leading, 16)
                }
            }

            Divider().padding(.horizontal, 16)

            // Add / Remove tee buttons
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        tees.append(TeeInput(name: "", rating: "", slope: ""))
                        // Grow yardage arrays to match new tee count
                        for i in holeInputs.indices {
                            while holeInputs[i].yardages.count < tees.count {
                                holeInputs[i].yardages.append("")
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
                            // Trim yardages on holes if we removed a tee
                            for i in holeInputs.indices {
                                while holeInputs[i].yardages.count > tees.count {
                                    holeInputs[i].yardages.removeLast()
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
                        .foregroundStyle(.black.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    // MARK: - Scorecard section

    private var scorecardSection: some View {
        VStack(spacing: 0) {
            // Compact header
            HStack(spacing: 0) {
                Text("HOLE").frame(width: 38, alignment: .leading)
                Text("PAR").frame(width: 34, alignment: .center)
                Text("HCP").frame(width: 34, alignment: .center)
                ForEach(0..<tees.count, id: \.self) { t in
                    Text(teeAbbr(t))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.black.opacity(0.35))
            .kerning(0.3)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 12)

            // Hole rows
            ForEach(0..<18, id: \.self) { idx in
                let isExpanded = expandedHole == idx

                VStack(spacing: 0) {
                    // Summary row — always visible, tappable
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            expandedHole = isExpanded ? nil : idx
                        }
                    } label: {
                        holeCompactRow(idx: idx)
                    }
                    .buttonStyle(.plain)

                    // Expanded edit row
                    if isExpanded {
                        holeEditView(idx: idx)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Front 9 / Back 9 subtotals
                if idx == 8 {
                    Divider().padding(.horizontal, 12)
                    subtotalRow(label: "OUT", range: 0..<9)
                }

                if idx < 17 || idx == 17 {
                    Divider().padding(.horizontal, 12).opacity(idx == 8 ? 0 : 0.5)
                }
            }

            Divider().padding(.horizontal, 12)
            subtotalRow(label: "IN", range: 9..<18)

            Divider().padding(.horizontal, 12)
            subtotalRow(label: "TOT", range: 0..<18)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private func teeAbbr(_ index: Int) -> String {
        guard index < tees.count else { return "" }
        let n = tees[index].name
        if n.isEmpty { return "T\(index + 1)" }
        return String(n.prefix(4)).uppercased()
    }

    private func holeCompactRow(idx: Int) -> some View {
        let hole = holeInputs[idx]
        let isExpanded = expandedHole == idx
        let parText = (3...5).contains(hole.par) ? "\(hole.par)" : "—"
        let handicapText = (1...18).contains(hole.handicap) ? "\(hole.handicap)" : "—"

        return HStack(spacing: 0) {
            Text("\(hole.number)")
                .font(.system(size: 14, weight: isExpanded ? .bold : .medium))
                .foregroundStyle(.black)
                .frame(width: 38, alignment: .leading)
            Text(parText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.65))
                .frame(width: 34, alignment: .center)
            Text(handicapText)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isExpanded ? Color.black.opacity(0.03) : Color.clear)
    }

    private func holeEditView(idx: Int) -> some View {
        VStack(spacing: 10) {
            // Par picker
            HStack {
                Text("Par")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                Spacer()
                HStack(spacing: 6) {
                    ForEach([3, 4, 5], id: \.self) { p in
                        Button {
                            holeInputs[idx].par = p
                        } label: {
                            Text("\(p)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(holeInputs[idx].par == p ? .white : .black)
                                .frame(width: 38, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(holeInputs[idx].par == p ? Color.black : Color.black.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.12), value: holeInputs[idx].par)
                    }
                }
            }

            // Handicap
            HStack {
                Text("Handicap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.55))
                Spacer()
                HStack(spacing: 0) {
                    Button {
                        if holeInputs[idx].handicap > 1 {
                            holeInputs[idx].handicap -= 1
                        } else {
                            holeInputs[idx].handicap = 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.55))
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                    }
                    .buttonStyle(.plain)

                    Text((1...18).contains(holeInputs[idx].handicap) ? "\(holeInputs[idx].handicap)" : "—")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .monospacedDigit()
                        .frame(width: 34, alignment: .center)

                    Button {
                        if holeInputs[idx].handicap < 1 {
                            holeInputs[idx].handicap = 1
                        } else if holeInputs[idx].handicap < 18 {
                            holeInputs[idx].handicap += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.55))
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
                    // Ensure yardages array is big enough
                    let binding = yardageBinding(hole: idx, tee: t)
                    TextField("yds", text: binding)
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

    /// Returns a Binding<String> for the yardage of hole at `hole` index, tee at `tee` index.
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

    private func subtotalRow(label: String, range: Range<Int>) -> some View {
        let parSum = holeInputs[range].reduce(0) { $0 + $1.par }
        return HStack(spacing: 0) {
            Text(label)
                .frame(width: 38, alignment: .leading)
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
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.black)
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.03))
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, canSave else { return }

        isSaving = true

        let teePayload = tees.compactMap { tee -> (name: String, rating: Double?, slope: Double?, yardage: Int?)? in
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
                let savedRow = try await DataService.shared.saveCourse(
                    name: trimmedName,
                    location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                    notes: nil,
                    colorTheme: Self.themes[selectedTheme].name,
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

// MARK: - Input models

struct TeeInput: Identifiable {
    let id = UUID()
    var databaseId: Int? = nil
    var name: String
    var rating: String
    var slope: String
}

struct HoleInput {
    let number: Int
    var par: Int = 0
    var handicap: Int = 0
    var yardages: [String] = []  // one per tee, as strings for text field binding

    init(number: Int, yardages: [String] = []) {
        self.number = number
        self.yardages = yardages
    }

    init(number: Int, par: Int, handicap: Int, yardages: [String]) {
        self.number = number
        self.par = par
        self.handicap = handicap
        self.yardages = yardages
    }
}
