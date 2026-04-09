//
// AddCourseSheet.swift
// Form sheet for creating a new course.
//

import SwiftUI

struct AddCourseSheet: View {
    enum PresentationStyle {
        case sheet
        case embedded
    }

    var onDismiss: () -> Void
    var onSave: (Course) -> Void
    var presentationStyle: PresentationStyle = .sheet
    var isVisible: Bool = true
    var existingCourse: Course? = nil
    var showsPreviewHeader: Bool = true

    // Course info
    @State private var name     = ""
    @State private var location = ""

    // Theme
    @State private var selectedPresetTheme = "Forest"
    @State private var usesCustomTheme = false
    @State private var customThemeColor = Color(red: 0.10, green: 0.48, blue: 0.42)
    @State private var customThemeSecondaryColor = Color(red: 0.32, green: 0.82, blue: 0.72)
    @State private var usesCustomGradient = false
    @State private var isThemeCardExpanded = false

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
    @State private var dismissButtonRotation: Double = 0

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

    static let themePresets: [String] = ["Forest", "Ocean", "Dusk", "Desert", "Ember", "Mint"]

    init(
        onDismiss: @escaping () -> Void,
        onSave: @escaping (Course) -> Void,
        presentationStyle: PresentationStyle = .sheet,
        isVisible: Bool = true,
        existingCourse: Course? = nil,
        showsPreviewHeader: Bool = true
    ) {
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.presentationStyle = presentationStyle
        self.isVisible = isVisible
        self.existingCourse = existingCourse
        self.showsPreviewHeader = showsPreviewHeader

        let defaultTheme = Self.themes.first?.colors ?? [Color(red: 0.03, green: 0.25, blue: 0.09), Color(red: 0.30, green: 0.68, blue: 0.22)]
        let accentColors = existingCourse?.accentColors ?? defaultTheme
        let primaryColor = accentColors.first ?? defaultTheme[0]
        let secondaryColor = accentColors.dropFirst().first ?? primaryColor
        let matchedPreset = Self.matchedPresetThemeName(for: accentColors)
        let isCustomTheme = existingCourse != nil && matchedPreset == nil
        let isCustomGradient = isCustomTheme && !Self.colorsApproximatelyEqual(primaryColor, secondaryColor)

        _name = State(initialValue: existingCourse?.name ?? "")
        _location = State(initialValue: existingCourse?.location ?? "")
        _selectedPresetTheme = State(initialValue: matchedPreset ?? "Forest")
        _usesCustomTheme = State(initialValue: isCustomTheme)
        _customThemeColor = State(initialValue: primaryColor)
        _customThemeSecondaryColor = State(initialValue: isCustomGradient ? secondaryColor : primaryColor)
        _usesCustomGradient = State(initialValue: isCustomGradient)
        _tees = State(initialValue: existingCourse?.tees.map {
            TeeInput(
                databaseId: $0.databaseId,
                name: $0.name,
                rating: String(format: "%.1f", $0.rating),
                slope: "\($0.slope)"
            )
        } ?? [
            TeeInput(name: "", rating: "", slope: ""),
        ])
        _holeInputs = State(initialValue: existingCourse?.holes.map { hole in
            HoleInput(
                number: hole.number,
                par: hole.par,
                handicap: hole.handicap,
                yardages: hole.yardages.map { "\($0)" }
            )
        } ?? (1...18).map { HoleInput(number: $0, yardages: [""]) })
    }

    private var horizontalCardInset: CGFloat {
        presentationStyle == .sheet ? Theme.Spacing.pageHorizontal : 0
    }

    private var previewCardHeight: CGFloat? {
        presentationStyle == .embedded ? 212 : nil
    }

    private var selectedThemeColors: [Color] {
        if usesCustomTheme {
            return usesCustomGradient ? [customThemeColor, customThemeSecondaryColor] : [customThemeColor, customThemeColor]
        }

        return Self.themes.first(where: { $0.name == selectedPresetTheme })?.colors ?? Self.themes[0].colors
    }

    private var themeCardExpandedHeight: CGFloat {
        usesCustomGradient ? 252 : 208
    }

    private var selectedThemeLabel: String {
        usesCustomTheme ? (usesCustomGradient ? "Custom Gradient" : "Custom Color") : selectedPresetTheme
    }

    private var selectedThemeStorageValue: String {
        guard usesCustomTheme else { return selectedPresetTheme }

        if usesCustomGradient {
            return "CustomGradient:\(Self.hexString(for: customThemeColor))-\(Self.hexString(for: customThemeSecondaryColor))"
        }

        return "CustomSolid:\(Self.hexString(for: customThemeColor))"
    }

    private var customThemeBinding: Binding<Color> {
        Binding(
            get: { customThemeColor },
            set: { newValue in
                usesCustomTheme = true
                customThemeColor = newValue
            }
        )
    }

    private var customThemeSecondaryBinding: Binding<Color> {
        Binding(
            get: { customThemeSecondaryColor },
            set: { newValue in
                usesCustomTheme = true
                usesCustomGradient = true
                customThemeSecondaryColor = newValue
            }
        )
    }

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
        Group {
            if presentationStyle == .embedded {
                embeddedContent
            } else {
                sheetContent
            }
        }
        .alert("Unable to Save Course", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "Please check the course details and try again.")
        }
    }

    private var sheetContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            formContent
        }
        .ignoresSafeArea(edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.canvas.ignoresSafeArea())
    }

    private var embeddedContent: some View {
        formContent
            .padding(.bottom, Theme.Spacing.huge)
    }

    private var formContent: some View {
        let sectionIndexOffset = showsPreviewHeader ? 1 : 0

        return VStack(alignment: .leading, spacing: 0) {
            if showsPreviewHeader {
                previewHeader
                    .sequencedVisibility(
                        index: 0,
                        isVisible: isVisible,
                        hiddenOffset: 30,
                        hiddenScale: 0.998,
                        enterAnimation: Theme.Animation.bouncy,
                        exitAnimation: Theme.Animation.tabExit,
                        enterStagger: 0.045,
                        exitStagger: 0.03
                    )
            }

            VStack(alignment: .leading, spacing: 0) {
                sectionGroup(index: sectionIndexOffset, label: "COLOR THEME") {
                    themeCard
                }

                sectionGroup(index: sectionIndexOffset + 1, label: "COURSE INFO") {
                    infoCard
                }

                sectionGroup(index: sectionIndexOffset + 2, label: "TEES") {
                    teesSection
                }

                sectionGroup(index: sectionIndexOffset + 3, label: "SCORECARD") {
                    scorecardSection
                }

                saveButton
                    .sequencedVisibility(
                        index: sectionIndexOffset + 4,
                        isVisible: isVisible,
                        hiddenOffset: 26,
                        hiddenScale: 0.998,
                        enterAnimation: Theme.Animation.bouncy,
                        exitAnimation: Theme.Animation.tabExit,
                        enterStagger: 0.05,
                        exitStagger: 0.03
                    )
            }
            .padding(.horizontal, horizontalCardInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            if presentationStyle == .sheet {
                Theme.Colors.canvas.ignoresSafeArea()
            } else {
                Color.clear
            }
        }
    }

    private func sectionGroup<Content: View>(index: Int, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(label)
            content()
        }
        .sequencedVisibility(
            index: index,
            isVisible: isVisible,
            hiddenOffset: 28,
            hiddenScale: 0.998,
            enterAnimation: Theme.Animation.bouncy,
            exitAnimation: Theme.Animation.tabExit,
            enterStagger: 0.05,
            exitStagger: 0.03
        )
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(isSaving ? "Saving..." : (existingCourse == nil ? "Add Course" : "Save Changes"))
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
    }

    // MARK: - Header (live preview)

    private var previewHeader: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: selectedThemeColors,
                startPoint: .leading, endPoint: .trailing
            )
            .overlay(
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear],
                    startPoint: .topLeading, endPoint: .center
                )
            )

            if presentationStyle == .sheet {
                Button {
                    withAnimation(Theme.Animation.snappy) {
                        dismissButtonRotation += 90
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.22), in: Circle())
                        .rotationEffect(.degrees(dismissButtonRotation))
                }
                .padding(.top, 56)
                .padding(.trailing, Theme.Spacing.md)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(name.isEmpty ? "New Course" : name)
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.sm) {
                    if !location.isEmpty {
                        Text(location)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.70))
                    } else {
                        Text("Add location")
                            .font(Theme.Typography.caption)
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
            .padding(.top, presentationStyle == .sheet ? 80 : 32)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewCardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .themeShadow(Theme.Shadow.prominent)
        .padding(.horizontal, horizontalCardInset)
        .padding(.top, presentationStyle == .sheet ? 0 : Theme.Spacing.sm)
        .animation(Theme.Animation.smooth, value: selectedThemeStorageValue)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.captionSmall)
            .foregroundStyle(Theme.Colors.textTertiary)
            .kerning(1.0)
            .padding(.top, 26)
            .padding(.bottom, Theme.Spacing.xs)
    }

    // MARK: - Color theme grid

    private var themeCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(Theme.Animation.smooth) {
                    isThemeCardExpanded.toggle()
                }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: selectedThemeColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous)
                                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedThemeLabel)
                            .font(Theme.Typography.bodySemibold)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Choose a preset or open the color wheel.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(isThemeCardExpanded ? 180 : 0))
                }
                .padding(Theme.Spacing.md)
            }
            .buttonStyle(ScorlyPressStyle())

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Divider()

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Self.themePresets, id: \.self) { presetName in
                        let presetColors = Self.themes.first(where: { $0.name == presetName })?.colors ?? selectedThemeColors
                        let isSelected = !usesCustomTheme && selectedPresetTheme == presetName

                        Button {
                            withAnimation(Theme.Animation.bouncy) {
                                usesCustomTheme = false
                                selectedPresetTheme = presetName
                            }
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: presetColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .strokeBorder(isSelected ? Theme.Colors.accent : .white.opacity(0.85), lineWidth: isSelected ? 2.5 : 1)
                                )
                                .scaleEffect(isSelected ? 1.06 : 1)
                        }
                        .buttonStyle(ScorlyPressStyle())
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Label(usesCustomGradient ? "Primary" : "Color", systemImage: "paintpalette")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Spacer()

                    ColorPicker("", selection: customThemeBinding, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(customThemeColor)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(usesCustomTheme ? Theme.Colors.accent : Theme.Colors.whisperBorder, lineWidth: usesCustomTheme ? 2.5 : 1)
                        )
                }

                if usesCustomGradient {
                    HStack(spacing: Theme.Spacing.md) {
                        Label("Secondary", systemImage: "circle.lefthalf.filled")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Spacer()

                        ColorPicker("", selection: customThemeSecondaryBinding, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(customThemeSecondaryColor)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.Colors.accent, lineWidth: 2.5)
                            )
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        withAnimation(Theme.Animation.snappy) {
                            usesCustomTheme = true
                            usesCustomGradient = false
                        }
                    } label: {
                        Text("Solid")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(usesCustomTheme && !usesCustomGradient ? Color.white : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .fill(usesCustomTheme && !usesCustomGradient ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.06))
                            )
                    }
                    .buttonStyle(ScorlyPressStyle())

                    Button {
                        withAnimation(Theme.Animation.snappy) {
                            usesCustomTheme = true
                            usesCustomGradient = true
                        }
                    } label: {
                        Text("Gradient")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(usesCustomTheme && usesCustomGradient ? Color.white : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .fill(usesCustomTheme && usesCustomGradient ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.06))
                            )
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
            .frame(maxHeight: isThemeCardExpanded ? themeCardExpandedHeight : 0, alignment: .top)
            .clipped()
            .opacity(isThemeCardExpanded ? 1 : 0)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1)
        )
        .themeShadow(Theme.Shadow.subtle)
        .animation(Theme.Animation.smooth, value: isThemeCardExpanded)
    }

    // MARK: - Info card

    private var infoCard: some View {
        VStack(spacing: 0) {
            formRow(label: "Name") {
                TextField("e.g. Pebble Beach", text: $name)
                    .font(Theme.Typography.body)
                    .multilineTextAlignment(.trailing)
            }
            Divider().padding(.leading, Theme.Spacing.md)
            formRow(label: "Location") {
                TextField("City, State", text: $location)
                    .font(Theme.Typography.body)
                    .multilineTextAlignment(.trailing)
            }
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            content()
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
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
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, Theme.Spacing.xs + 2)

            Divider().padding(.horizontal, Theme.Spacing.md)

            // Tee rows
            ForEach($tees) { $tee in
                HStack(spacing: 0) {
                    TextField("Tee name", text: $tee.name)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("72.0", text: $tee.rating)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .frame(width: 62)
                    TextField("125", text: $tee.slope)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)

                if tee.id != tees.last?.id {
                    Divider().padding(.leading, Theme.Spacing.md)
                }
            }

            Divider().padding(.horizontal, Theme.Spacing.md)

            // Add / Remove tee buttons
            HStack {
                Button {
                    withAnimation(Theme.Animation.smooth) {
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
                                .font(Theme.Typography.caption)
                            Text("Remove")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .buttonStyle(ScorlyPressStyle())
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
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
            .foregroundStyle(Theme.Colors.textTertiary)
            .kerning(0.3)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs + 2)

            Divider().padding(.horizontal, Theme.Spacing.sm)

            // Hole rows
            ForEach(0..<18, id: \.self) { idx in
                let isExpanded = expandedHole == idx

                VStack(spacing: 0) {
                    // Summary row — always visible, tappable
                    Button {
                        withAnimation(Theme.Animation.smooth) {
                            expandedHole = isExpanded ? nil : idx
                        }
                    } label: {
                        holeCompactRow(idx: idx)
                    }
                    .buttonStyle(ScorlyPressStyle())

                    // Expanded edit row
                    holeEditView(idx: idx)
                        .frame(maxHeight: isExpanded ? holeEditHeight : 0, alignment: .top)
                        .clipped()
                }

                // Front 9 / Back 9 subtotals
                if idx == 8 {
                    Divider().padding(.horizontal, Theme.Spacing.sm)
                    subtotalRow(label: "OUT", range: 0..<9)
                }

                if idx < 17 || idx == 17 {
                    Divider().padding(.horizontal, Theme.Spacing.sm).opacity(idx == 8 ? 0 : 0.5)
                }
            }

            Divider().padding(.horizontal, Theme.Spacing.sm)
            subtotalRow(label: "IN", range: 9..<18)

            Divider().padding(.horizontal, Theme.Spacing.sm)
            subtotalRow(label: "TOT", range: 0..<18)
        }
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).strokeBorder(Theme.Colors.whisperBorder, lineWidth: 1))
        .themeShadow(Theme.Shadow.subtle)
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
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isExpanded ? Theme.Colors.accent : Color.clear)
                    .frame(width: 30, height: 30)
                    .scaleEffect(isExpanded ? 1 : 0.86)

                Text("\(hole.number)")
                    .font(.system(size: 14, weight: isExpanded ? .bold : .medium))
                    .foregroundStyle(isExpanded ? Color.white : Theme.Colors.textPrimary)
                    .monospacedDigit()
            }
            .frame(width: 38, alignment: .leading)
            .animation(Theme.Animation.bouncy, value: isExpanded)
            Text(parText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 34, alignment: .center)
            Text(handicapText)
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
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(isExpanded ? Theme.Colors.textPrimary.opacity(0.03) : Color.clear)
    }

    private var holeEditHeight: CGFloat {
        112 + CGFloat(tees.count) * 34
    }

    private func holeEditView(idx: Int) -> some View {
        VStack(spacing: Theme.Spacing.xs + 2) {
            // Par picker
            HStack {
                Text("Par")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                HStack(spacing: Theme.Spacing.xxs + 2) {
                    ForEach([3, 4, 5], id: \.self) { p in
                        Button {
                            holeInputs[idx].par = p
                        } label: {
                            Text("\(p)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(holeInputs[idx].par == p ? .white : Theme.Colors.textPrimary)
                                .frame(width: 38, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.sm - 1, style: .continuous)
                                        .fill(holeInputs[idx].par == p ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(0.06))
                                )
                        }
                        .buttonStyle(ScorlyPressStyle())
                        .animation(Theme.Animation.snappy, value: holeInputs[idx].par)
                    }
                }
            }

            // Handicap
            HStack {
                Text("Handicap")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
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
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.textPrimary.opacity(0.06)))
                    }
                    .buttonStyle(ScorlyPressStyle())

                    Text((1...18).contains(holeInputs[idx].handicap) ? "\(holeInputs[idx].handicap)" : "—")
                        .font(Theme.Typography.bodySemibold)
                        .foregroundStyle(Theme.Colors.textPrimary)
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
                            .foregroundStyle(Theme.Colors.textSecondary)
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
                    // Ensure yardages array is big enough
                    let binding = yardageBinding(hole: idx, tee: t)
                    TextField("yds", text: binding)
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
        .foregroundStyle(Theme.Colors.textPrimary)
        .monospacedDigit()
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(Theme.Colors.textPrimary.opacity(0.03))
    }

    private static func hexString(for color: Color) -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return String(
                format: "%02X%02X%02X",
                Int(red * 255),
                Int(green * 255),
                Int(blue * 255)
            )
        }
        #endif

        return "0B1215"
    }

    private static func matchedPresetThemeName(for colors: [Color]) -> String? {
        guard colors.count >= 2 else { return nil }

        return themes.first(where: { theme in
            guard theme.colors.count >= 2 else { return false }
            return colorsApproximatelyEqual(theme.colors[0], colors[0]) &&
                colorsApproximatelyEqual(theme.colors[1], colors[1])
        })?.name
    }

    private static func colorsApproximatelyEqual(_ lhs: Color, _ rhs: Color) -> Bool {
        #if canImport(UIKit)
        let left = UIColor(lhs)
        let right = UIColor(rhs)
        var leftRed: CGFloat = 0
        var leftGreen: CGFloat = 0
        var leftBlue: CGFloat = 0
        var leftAlpha: CGFloat = 0
        var rightRed: CGFloat = 0
        var rightGreen: CGFloat = 0
        var rightBlue: CGFloat = 0
        var rightAlpha: CGFloat = 0

        guard left.getRed(&leftRed, green: &leftGreen, blue: &leftBlue, alpha: &leftAlpha),
              right.getRed(&rightRed, green: &rightGreen, blue: &rightBlue, alpha: &rightAlpha) else {
            return false
        }

        let threshold: CGFloat = 0.03
        return abs(leftRed - rightRed) < threshold &&
            abs(leftGreen - rightGreen) < threshold &&
            abs(leftBlue - rightBlue) < threshold &&
            abs(leftAlpha - rightAlpha) < threshold
        #else
        return false
        #endif
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, canSave else { return }

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
                let savedRow: CourseRow

                if let courseId = existingCourse?.databaseId {
                    savedRow = try await DataService.shared.updateCourse(
                        courseId: courseId,
                        name: trimmedName,
                        location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                        notes: nil,
                        colorTheme: selectedThemeStorageValue,
                        tees: teePayload,
                        holes: holePayload,
                        teeHoleYardages: teeHoleYardages
                    )
                } else {
                    savedRow = try await DataService.shared.saveCourse(
                        name: trimmedName,
                        location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                        notes: nil,
                        colorTheme: selectedThemeStorageValue,
                        tees: teePayload.map { tee in
                            (name: tee.name, rating: tee.rating, slope: tee.slope, yardage: tee.yardage)
                        },
                        holes: holePayload,
                        teeHoleYardages: teeHoleYardages
                    )
                }

                await MainActor.run {
                    isSaving = false
                    onSave(Course(from: savedRow))
                    onDismiss()
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
