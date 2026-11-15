import SwiftUI

struct ScoreReaderDynamicTool: Identifiable {
    let token: String
    let title: String

    var id: String { token }
}

enum ScoreReaderDynamicTools {
    static let primary: [ScoreReaderDynamicTool] = [
        ScoreReaderDynamicTool(token: "f", title: "强"),
        ScoreReaderDynamicTool(token: "mf", title: "中强"),
        ScoreReaderDynamicTool(token: "p", title: "弱"),
        ScoreReaderDynamicTool(token: "mp", title: "中弱")
    ]

    static let additional: [ScoreReaderDynamicTool] = [
        ScoreReaderDynamicTool(token: "ppp", title: "极弱"),
        ScoreReaderDynamicTool(token: "pp", title: "很弱"),
        ScoreReaderDynamicTool(token: "ff", title: "很强"),
        ScoreReaderDynamicTool(token: "fff", title: "极强"),
        ScoreReaderDynamicTool(token: "fp", title: "强后弱"),
        ScoreReaderDynamicTool(token: "pf", title: "弱后强"),
        ScoreReaderDynamicTool(token: "sf", title: "突强"),
        ScoreReaderDynamicTool(token: "sfz", title: "特强重音"),
        ScoreReaderDynamicTool(token: "sff", title: "突强至很强"),
        ScoreReaderDynamicTool(token: "sffz", title: "突强至很强（Z）"),
        ScoreReaderDynamicTool(token: "sfp", title: "突强后弱"),
        ScoreReaderDynamicTool(token: "rfz", title: "加强"),
        ScoreReaderDynamicTool(token: "rf", title: "加强至强"),
        ScoreReaderDynamicTool(token: "fz", title: "强重音")
    ]

    static let all = primary + additional
}

struct ScoreReaderArticulationTool: Identifiable {
    let token: String
    let title: String
    let symbol: String
    /// A Bravura glyph drawn instead of `symbol` where a plain character can't show the mark.
    var musicGlyph: String? = nil

    var id: String { token }
}

enum ScoreReaderArticulationTools {
    private static let common: [ScoreReaderArticulationTool] = [
        ScoreReaderArticulationTool(token: "Accent", title: "重音", symbol: ">"),
        ScoreReaderArticulationTool(token: "Marcato", title: "强调", symbol: "^"),
        ScoreReaderArticulationTool(token: "Tenuto", title: "保持音", symbol: "-"),
        ScoreReaderArticulationTool(token: "Staccato", title: "跳音", symbol: ".")
    ]

    /// Its own button, ahead of Articulations, as in MuseScore's separate Fermatas palette:
    /// it also goes on rests, which the note-only articulations don't.
    static let fermata = ScoreReaderArticulationTool(
        token: "Fermata", title: "延长记号", symbol: "\u{E4C0}", musicGlyph: "\u{E4C0}"
    )

    private static let bowing: [ScoreReaderArticulationTool] = [
        ScoreReaderArticulationTool(token: "String Up", title: "上弓", symbol: "∨"),
        ScoreReaderArticulationTool(token: "String Down", title: "下弓", symbol: "П")
    ]

    static func tools(supportsBowingArticulations: Bool) -> [ScoreReaderArticulationTool] {
        supportsBowingArticulations ? common + bowing : common
    }
}

struct ScoreReaderArticulationMenuButton: View {
    let isEnabled: Bool
    var supportsBowingArticulations = false
    let addExpressionAction: (String) -> Void

    var body: some View {
        Menu {
            ForEach(ScoreReaderArticulationTools.tools(supportsBowingArticulations: supportsBowingArticulations)) { articulation in
                Button {
                    addExpressionAction(articulation.token)
                } label: {
                    Text("\(articulation.symbol)  \(articulation.title)")
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(">")
                    .font(.system(size: 21, weight: .medium))
                    .frame(height: 22)
                Text("演奏记号")
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.66)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(width: 68, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

struct ScoreReaderLineTool: Identifiable {
    let token: String
    let title: String
    let symbol: String

    var id: String { token }
}

enum ScoreReaderLineTools {
    static let primary: [ScoreReaderLineTool] = [
        ScoreReaderLineTool(token: "Slur", title: "连音线", symbol: "⌒"),
        ScoreReaderLineTool(token: "Crescendo", title: "渐强", symbol: "<"),
        ScoreReaderLineTool(token: "Decrescendo", title: "渐弱", symbol: ">")
    ]

    static let all: [ScoreReaderLineTool] = [
        ScoreReaderLineTool(token: "Pedal", title: "踏板", symbol: "Ped."),
        ScoreReaderLineTool(token: "8va", title: "8va", symbol: "8va"),
        ScoreReaderLineTool(token: "8vb", title: "8vb", symbol: "8vb")
    ]
}

struct ScoreReaderLinesMenuButton: View {
    let isEnabled: Bool
    let addExpressionAction: (String) -> Void

    var body: some View {
        Menu {
            ForEach(ScoreReaderLineTools.all) { line in
                Button {
                    addExpressionAction(line.token)
                } label: {
                    Text("\(line.symbol)  \(line.title)")
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("8va")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 22)
                Text("线条")
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(width: 68, height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

enum ScoreReaderCompactKeyboardSections: Equatable {
    case all
    case durationOnly
    case optionsOnly
}

struct ScoreReaderKeyboardContextToolbar: View {
    let editingState: ScoreEditingState
    let pendingPitchClass: Int?
    let pendingAccidentalKind: ScoreAccidentalKind?
    let isBusy: Bool
    var isCompact = false
    var usesPortraitGrid = false
    var compactSections: ScoreReaderCompactKeyboardSections = .all
    let applyDurationAction: (ScoreNoteDuration) -> Void
    let toggleDotAction: () -> Void
    let toggleRestAction: () -> Void
    let deleteSelectionAction: () -> Void
    let toggleTieAction: () -> Void
    let addTupletAction: (Int) -> Void
    let stackedChordInputEnabled: Bool
    let toggleStackedChordInputAction: () -> Void
    let setPitchClassAction: (Int, Bool) -> Void
    let prepareAccidentalAction: (ScoreAccidentalKind) -> Void
    let changeAccidentalAction: (ScoreAccidentalKind) -> Void
    @Binding var preferFlats: Bool
    /// Shows the up arrow that opens the More Notes row (iPad toolbar only for now).
    var moreNoteToolAction: ((ScoreReaderMoreNoteTool) -> Void)? = nil
    /// Stays open until the player closes it, across scores and launches.
    @AppStorage("Aria.NoteEntry.MoreNotesExpanded") var moreNotesExpanded = false

    var body: some View {
        if isCompact {
            if usesPortraitGrid {
                compactPortraitGridBody
            } else {
                compactBody
            }
        } else {
            regularBody
        }
    }

    private var regularBody: some View {
        VStack(spacing: 6) {
            if moreNotesExpanded, moreNoteToolAction != nil {
                regularScaledRow(moreNotesRow, minimumWidth: Self.moreNotesRowMinimumWidth)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            regularScaledRow(regularRow, minimumWidth: Self.regularRowMinimumWidth)
        }
    }

    @ViewBuilder
    private func regularScaledRow<Row: View>(_ row: Row, minimumWidth: CGFloat) -> some View {
        #if os(Android)
        // Skip's maxWidth frame doesn't shrink to the panel, so a row wider than the panel
        // (tablet portrait) ran off both edges. There the row is laid out at its narrowest
        // and scaled down to the panel's width, so every button shows without scrolling.
        GeometryReader { proxy in
            if proxy.size.width >= minimumWidth {
                regularRowCard(row, maxWidth: min(900, proxy.size.width - 20))
                    .frame(maxWidth: .infinity)
            } else {
                let scale = max(proxy.size.width, 1) / minimumWidth
                regularRowCard(row, maxWidth: nil)
                    .frame(width: minimumWidth, height: 72)
                    .scaleEffect(scale, anchor: .center)
                    .frame(width: proxy.size.width, height: 72)
            }
        }
        .frame(height: 72)
        #else
        regularRowCard(row, maxWidth: 900)
        #endif
    }

    /// Less common note tools, shown above the main row: shorter durations, double dot,
    /// beams, grace notes, ornaments, tremolo and double accidentals.
    private var moreNotesItems: [ScoreReaderMoreNotesItem] {
        let rhythm = canUseRhythmTools
        let note = canAddToSelectedNote
        // Column by column over the main row below: 32nd and 64th over the eighth and 16th,
        // double dot over the dot.
        return [
            ScoreReaderMoreNotesItem(id: "beam", glyph: "\u{266B}", title: "符杠", isEnabled: canChangeBeams,
                                     menu: ScoreReaderMoreNotesOption.beamModes),
            ScoreReaderMoreNotesItem(id: "trem", glyph: "\u{E222}", title: "震音", isEnabled: note,
                                     menu: ScoreReaderMoreNotesOption.tremolos, glyphOffset: -6),
            ScoreReaderMoreNotesItem(id: "acc", glyph: "\u{E560}", title: "短倚音", isEnabled: note,
                                     tool: .grace(.acciaccatura)),
            ScoreReaderMoreNotesItem(id: "app", glyph: "\u{E562}", title: "长倚音", isEnabled: note,
                                     tool: .grace(.appoggiatura)),
            ScoreReaderMoreNotesItem(id: "32", glyph: ScoreNoteDuration.thirtySecond.bravuraTextGlyph, title: "三十二分",
                                     isSelected: selectedDuration == .thirtySecond, isEnabled: rhythm,
                                     tool: .duration(.thirtySecond)),
            ScoreReaderMoreNotesItem(id: "64", glyph: ScoreNoteDuration.sixtyFourth.bravuraTextGlyph, title: "六十四分",
                                     isSelected: selectedDuration == .sixtyFourth, isEnabled: rhythm,
                                     tool: .duration(.sixtyFourth)),
            ScoreReaderMoreNotesItem(id: "dd", glyph: "\u{1D15F}..", title: "双附点",
                                     isSelected: selectedIsDoubleDotted, isEnabled: rhythm, tool: .doubleDot),
            ScoreReaderMoreNotesItem(id: "tr", glyph: "\u{E566}", title: "颤音", isEnabled: note, tool: .ornament("trill")),
            ScoreReaderMoreNotesItem(id: "mor", glyph: "\u{E56C}", title: "波音", isEnabled: note,
                                     tool: .ornament("mordent")),
            ScoreReaderMoreNotesItem(id: "turn", glyph: "\u{E567}", title: "回音", isEnabled: note, tool: .ornament("turn")),
            ScoreReaderMoreNotesItem(id: "arp", glyph: "\u{E63C}", title: "琶音", isEnabled: note,
                                     tool: .ornament("arpeggio"), glyphScale: 0.8),
            ScoreReaderMoreNotesItem(id: "bb", glyph: "\u{E264}", title: "重降", isEnabled: canChangeDoubleAccidental,
                                     tool: .doubleAccidental(sharp: false), glyphScale: 1.1, glyphOffset: 6),
            ScoreReaderMoreNotesItem(id: "x", glyph: "\u{E263}", title: "重升", isEnabled: canChangeDoubleAccidental,
                                     tool: .doubleAccidental(sharp: true), glyphScale: 1.6, glyphOffset: 3)
        ]
    }

    private var moreNotesRow: some View {
        let items = moreNotesItems
        return HStack(spacing: 0) {
            ForEach(items) { item in
                ScoreReaderMoreNotesButton(item: item, action: performMoreNotesTool)
                    .frame(minWidth: 0, maxWidth: .infinity)

                if item.id != items.last?.id {
                    ScoreReaderContextDivider()
                }
            }

            // An empty column over the main row's arrow keeps the two rows' columns in line.
            ScoreReaderContextDivider()
                .hidden()
            Color.clear
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: 1)
                .accessibilityHidden(true)
        }
    }

    /// Phones: the same tools as a strip that scrolls sideways.
    private var compactMoreNotesStrip: some View {
        MobileHintingHorizontalScrollView(hintHeight: 52) {
            HStack(spacing: 2) {
                ForEach(moreNotesItems) { item in
                    ScoreReaderMoreNotesButton(item: item, isCompact: true, action: performMoreNotesTool)
                }
            }
            .padding(.horizontal, 2)
            .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.6)
                    .allowsHitTesting(false)
            }
        }
    }

    private func performMoreNotesTool(_ tool: ScoreReaderMoreNoteTool) {
        moreNoteToolAction?(tool)
    }

    private var moreNotesToggle: some View {
        ScoreReaderPaletteButton(
            systemImage: moreNotesExpanded ? "chevron.down" : "chevron.up",
            isSelected: false,
            isEnabled: true,
            action: toggleMoreNotes
        )
        .accessibilityLabel(moreNotesExpanded ? "收起更多音符选项" : "更多音符选项")
    }

    private func toggleMoreNotes() {
        withAnimation(.easeInOut(duration: 0.2)) {
            moreNotesExpanded.toggle()
        }
    }

    /// Both iPad/tablet rows are 14 equal columns, so each More Notes tool sits over its main-row
    /// partner. Titled buttons are this wide; icon buttons stay 38.
    static let columnButtonWidth: CGFloat = 52
    /// 14 columns, 13 dividers (5) and the card's padding.
    private static let regularRowMinimumWidth: CGFloat = 14 * columnButtonWidth + 13 * 5 + 20
    private static let moreNotesRowMinimumWidth: CGFloat = regularRowMinimumWidth

    private func regularRowCard<Row: View>(_ row: Row, maxWidth: CGFloat?) -> some View {
        row
            .frame(maxWidth: maxWidth, minHeight: 58)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.09), lineWidth: 0.7)
            }
    }

    private var regularRow: some View {
        HStack(spacing: 0) {
            ScoreReaderPaletteButton(
                stackedChordIcon: true,
                isSelected: stackedChordInputEnabled,
                isEnabled: canUseStackedChordInput,
                action: toggleStackedChordInputAction
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            ScoreReaderContextDivider()

            ForEach(ScoreNoteDuration.toolbarDurations) { duration in
                ScoreReaderPaletteButton(
                    duration: duration,
                    isSelected: selectedDuration == duration,
                    isEnabled: canUseRhythmTools,
                    action: { applyDurationAction(duration) }
                )
                .frame(minWidth: 0, maxWidth: .infinity)

                if duration != ScoreNoteDuration.toolbarDurations.last {
                    ScoreReaderContextDivider()
                }
            }

            ScoreReaderContextDivider()

            ScoreReaderPaletteButton(
                textSymbol: "\u{1D15F}.",
                title: "附点",
                usesMusicFont: true,
                titledWidth: Self.columnButtonWidth,
                isSelected: selectedIsDotted,
                isEnabled: canUseRhythmTools,
                action: toggleDotAction
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            ScoreReaderContextDivider()

            ScoreReaderPaletteButton(
                textSymbol: "\u{1D13D}",
                title: "休止符",
                usesMusicFont: true,
                glyphBaselineOffset: 7,
                titledWidth: Self.columnButtonWidth,
                isSelected: selectedIsRest,
                isEnabled: canUseRhythmTools,
                action: toggleRestAction
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            ScoreReaderContextDivider()

            ScoreReaderPaletteButton(
                textSymbol: "⌒",
                title: "延音线",
                titledWidth: Self.columnButtonWidth,
                isSelected: editingState.selection?.isTiedForward == true,
                isEnabled: editingState.selection?.kind == .note && !isBusy,
                action: toggleTieAction
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            ScoreReaderContextDivider()

            ScoreReaderTupletMenuButton(
                width: Self.columnButtonWidth,
                isEnabled: canUseRhythmTools,
                action: addTupletAction
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            ScoreReaderContextDivider()

            accidentalButton(.flat)
            ScoreReaderContextDivider()
            accidentalButton(.natural)
            ScoreReaderContextDivider()
            accidentalButton(.sharp)

            if moreNoteToolAction != nil {
                ScoreReaderContextDivider()
                moreNotesToggle
                    .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if moreNotesExpanded, moreNoteToolAction != nil, compactSections != .optionsOnly {
                compactSectionTitle("More Notes")
                    .padding(.leading, 4)
                compactMoreNotesStrip
            }

            if compactSections != .optionsOnly {
                compactSectionTitle("Duration")
                    .padding(.leading, 4)

                MobileHintingHorizontalScrollView(hintHeight: 46) {
                    HStack(spacing: 0) {
                        ForEach(ScoreNoteDuration.toolbarDurations) { duration in
                            ScoreReaderCompactPaletteButton(
                                duration: duration,
                                width: 60,
                                isSelected: selectedDuration == duration,
                                isEnabled: canUseRhythmTools,
                                action: { applyDurationAction(duration) }
                            )
                            .accessibilityLabel(duration.noteEntryTitle)

                            ScoreReaderCompactGroupedDivider()
                        }

                        ScoreReaderCompactPaletteButton(
                            textSymbol: "·",
                            width: 60,
                            isSelected: selectedIsDotted,
                            isEnabled: canUseRhythmTools,
                            action: toggleDotAction
                        )
                        .accessibilityLabel(selectedIsDotted ? "移除附点" : "添加附点")

                        ScoreReaderCompactGroupedDivider()

                        ScoreReaderCompactTupletMenuButton(
                            width: 60,
                            isEnabled: canUseRhythmTools,
                            action: addTupletAction
                        )
                    }
                    .padding(.horizontal, 1)
                    .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 0.6)
                            .allowsHitTesting(false)
                    }
                }
            }

            if compactSections != .durationOnly {
                compactSectionTitle("Accidentals & Options")
                    .padding(.top, compactSections == .all ? 2 : 0)
                    .padding(.leading, 4)

                HStack(spacing: 10) {
                    ScoreReaderCompactControlGroup {
                        compactGroupedAccidentalButton(.sharp)
                        ScoreReaderCompactGroupedDivider()
                        compactGroupedAccidentalButton(.flat)
                        ScoreReaderCompactGroupedDivider()
                        compactGroupedAccidentalButton(.natural)
                    }

                    ScoreReaderCompactControlGroup {
                        ScoreReaderCompactGroupedPaletteButton(
                            textSymbol: "\u{1D13D}",
                            usesMusicFont: true,
                            glyphBaselineOffset: 10,
                            isSelected: selectedIsRest,
                            isEnabled: canUseRhythmTools,
                            accessibilityLabel: selectedIsRest ? "音符输入" : "输入休止符",
                            action: toggleRestAction
                        )
                        ScoreReaderCompactGroupedDivider()
                        ScoreReaderCompactGroupedPaletteButton(
                            systemImage: "trash",
                            isSelected: false,
                            isEnabled: editingState.canDeleteSelection && !isBusy,
                            accessibilityLabel: "删除选区",
                            action: deleteSelectionAction
                        )
                        ScoreReaderCompactGroupedDivider()
                        ScoreReaderCompactGroupedPaletteButton(
                            textSymbol: "⌒",
                            isSelected: editingState.selection?.isTiedForward == true,
                            isEnabled: editingState.selection?.kind == .note && !isBusy,
                            accessibilityLabel: "延音线",
                            action: toggleTieAction
                        )
                        ScoreReaderCompactGroupedDivider()
                        ScoreReaderCompactGroupedPaletteButton(
                            stackedChordIcon: true,
                            isSelected: stackedChordInputEnabled,
                            isEnabled: canUseStackedChordInput,
                            accessibilityLabel: stackedChordInputEnabled ? "单音输入" : "构建和弦",
                            action: toggleStackedChordInputAction
                        )
                    }

                    if moreNoteToolAction != nil {
                        ScoreReaderCompactControlGroup {
                            ScoreReaderCompactGroupedPaletteButton(
                                systemImage: moreNotesExpanded ? "chevron.down" : "chevron.up",
                                isSelected: moreNotesExpanded,
                                isEnabled: true,
                                accessibilityLabel: moreNotesExpanded ? "收起更多音符选项" : "更多音符选项",
                                action: toggleMoreNotes
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactPortraitGridBody: some View {
        VStack(spacing: 4) {
            if moreNotesExpanded, moreNoteToolAction != nil {
                compactMoreNotesStrip
            }

            HStack(spacing: 4) {
                ForEach(ScoreNoteDuration.toolbarDurations) { duration in
                    ScoreReaderCompactGridPaletteButton(
                        duration: duration,
                        isSelected: selectedDuration == duration,
                        isEnabled: canUseRhythmTools,
                        accessibilityLabel: duration.noteEntryTitle,
                        action: { applyDurationAction(duration) }
                    )
                }

                ScoreReaderCompactGridPaletteButton(
                    textSymbol: "·",
                    isSelected: selectedIsDotted,
                    isEnabled: canUseRhythmTools,
                    accessibilityLabel: selectedIsDotted ? "移除附点" : "添加附点",
                    action: toggleDotAction
                )

                if moreNoteToolAction != nil {
                    // Top row: the More Notes strip opens right above it.
                    ScoreReaderCompactGridPaletteButton(
                        systemImage: moreNotesExpanded ? "chevron.down" : "chevron.up",
                        isSelected: moreNotesExpanded,
                        isEnabled: true,
                        accessibilityLabel: moreNotesExpanded ? "收起更多音符选项" : "更多音符选项",
                        action: toggleMoreNotes
                    )
                } else {
                    ScoreReaderCompactGridTupletMenuButton(
                        isEnabled: canUseRhythmTools,
                        action: addTupletAction
                    )
                }
            }

            HStack(spacing: 4) {
                compactGridAccidentalButton(.sharp)
                compactGridAccidentalButton(.flat)
                compactGridAccidentalButton(.natural)

                ScoreReaderCompactGridPaletteButton(
                    stackedChordIcon: true,
                    isSelected: stackedChordInputEnabled,
                    isEnabled: canUseStackedChordInput,
                    accessibilityLabel: stackedChordInputEnabled ? "单音输入" : "构建和弦",
                    action: toggleStackedChordInputAction
                )

                ScoreReaderCompactGridPaletteButton(
                    textSymbol: "⌒",
                    isSelected: editingState.selection?.isTiedForward == true,
                    isEnabled: editingState.selection?.kind == .note && !isBusy,
                    accessibilityLabel: "延音线",
                    action: toggleTieAction
                )

                ScoreReaderCompactGridPaletteButton(
                    textSymbol: "\u{1D13D}",
                    usesMusicFont: true,
                    glyphBaselineOffset: 10,
                    musicFontSize: 26,
                    glyphVerticalOffset: -3,
                    isSelected: selectedIsRest,
                    isEnabled: canUseRhythmTools,
                    accessibilityLabel: selectedIsRest ? "音符输入" : "输入休止符",
                    action: toggleRestAction
                )

                if moreNoteToolAction != nil {
                    ScoreReaderCompactGridTupletMenuButton(
                        isEnabled: canUseRhythmTools,
                        action: addTupletAction
                    )
                }

                ScoreReaderCompactGridPaletteButton(
                    systemImage: "trash",
                    isSelected: false,
                    isEnabled: editingState.canDeleteSelection && !isBusy,
                    accessibilityLabel: "删除选区",
                    action: deleteSelectionAction
                )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }

    private func compactSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Color.black.opacity(0.42))
    }

    private func compactGroupedAccidentalButton(_ accidentalKind: ScoreAccidentalKind) -> some View {
        ScoreReaderCompactGroupedPaletteButton(
            textSymbol: symbol(for: accidentalKind),
            isSelected: selectedAccidental == accidentalKind,
            isEnabled: canEditPitch,
            accessibilityLabel: title(for: accidentalKind),
            action: { applyAccidental(accidentalKind) }
        )
    }

    private func compactGridAccidentalButton(_ accidentalKind: ScoreAccidentalKind) -> some View {
        ScoreReaderCompactGridPaletteButton(
            textSymbol: symbol(for: accidentalKind),
            isSelected: selectedAccidental == accidentalKind,
            isEnabled: canEditPitch,
            accessibilityLabel: title(for: accidentalKind),
            action: { applyAccidental(accidentalKind) }
        )
    }

    private func accidentalButton(_ accidentalKind: ScoreAccidentalKind) -> some View {
        ScoreReaderPaletteButton(
            textSymbol: symbol(for: accidentalKind),
            title: title(for: accidentalKind),
            titledWidth: Self.columnButtonWidth,
            isSelected: selectedAccidental == accidentalKind,
            isEnabled: canEditPitch,
            action: { applyAccidental(accidentalKind) }
        )
        .frame(minWidth: 0, maxWidth: .infinity)
    }

    private func compactAccidentalButton(_ accidentalKind: ScoreAccidentalKind) -> some View {
        ScoreReaderCompactPaletteButton(
            textSymbol: symbol(for: accidentalKind),
            isSelected: selectedAccidental == accidentalKind,
            isEnabled: canEditPitch,
            action: { applyAccidental(accidentalKind) }
        )
    }

    private var canEditPitch: Bool {
        (
            editingState.selection?.canChangePitch == true
            || editingState.noteInputEnabled
            || editingState.selection?.kind == .rest
            || editingState.selection?.kind == .measure
        ) && !isBusy
    }

    private var canUseRhythmTools: Bool {
        (editingState.noteInputEnabled || editingState.selection != nil) && !isBusy
    }

    private var canUseStackedChordInput: Bool {
        (
            editingState.noteInputEnabled
            || editingState.selection?.kind == .note
            || editingState.selection?.kind == .rest
            || editingState.selection?.kind == .measure
        ) && !editingState.noteInputInsertsRests && !isBusy
    }

    private var selectedDuration: ScoreNoteDuration {
        editingState.noteInputEnabled ? editingState.duration : (editingState.selection?.duration ?? editingState.duration)
    }

    private var selectedIsRest: Bool {
        editingState.noteInputEnabled ? editingState.noteInputInsertsRests : editingState.selection?.kind == .rest
    }

    private var selectedIsDotted: Bool {
        editingState.noteInputEnabled ? editingState.noteInputIsDotted : editingState.selection?.isDotted == true
    }

    private var selectedIsDoubleDotted: Bool {
        editingState.noteInputEnabled
            ? editingState.noteInputIsDoubleDotted
            : editingState.selection?.isDoubleDotted == true
    }

    /// Grace notes and ornaments attach to a selected note.
    private var canAddToSelectedNote: Bool {
        editingState.selection?.kind == .note && !isBusy
    }

    /// Beam modes apply to notes and rests, not to a selected slur or text.
    private var canChangeBeams: Bool {
        let kind = editingState.selection?.kind
        return (editingState.noteInputEnabled || kind == .note || kind == .rest || kind == .measure) && !isBusy
    }

    /// Double accidentals change the selected note, or in note input the note just entered.
    private var canChangeDoubleAccidental: Bool {
        (editingState.selection?.canChangePitch == true || editingState.noteInputEnabled) && !isBusy
    }

    private var selectedAccidental: ScoreAccidentalKind? {
        editingState.noteInputEnabled
            ? pendingAccidentalKind
            : editingState.selection?.accidentalKind
    }

    private func applyAccidental(_ accidentalKind: ScoreAccidentalKind) {
        switch accidentalKind {
        case .flat:
            preferFlats = true
        case .sharp, .natural:
            preferFlats = false
        }

        if editingState.noteInputEnabled {
            prepareAccidentalAction(accidentalKind)
        } else if editingState.selection?.canChangePitch == true {
            changeAccidentalAction(accidentalKind)
        } else if let pitchClass = preparedPitchClass(for: accidentalKind) {
            setPitchClassAction(pitchClass, preferFlats)
        }
    }

    private func preparedPitchClass(for accidentalKind: ScoreAccidentalKind) -> Int? {
        guard let pendingPitchClass else {
            return nil
        }

        let naturalPitchClasses = [0, 2, 4, 5, 7, 9, 11]
        var bestStep = 0
        var bestDistance = Int.max
        for (step, naturalPitchClass) in naturalPitchClasses.enumerated() {
            let upwardDistance = (pendingPitchClass - naturalPitchClass + 12) % 12
            let distance = min(upwardDistance, 12 - upwardDistance)
            if distance < bestDistance {
                bestDistance = distance
                bestStep = step
            }
        }

        let accidentalOffset: Int
        switch accidentalKind {
        case .natural:
            accidentalOffset = 0
        case .sharp:
            accidentalOffset = 1
        case .flat:
            accidentalOffset = -1
        }

        return (naturalPitchClasses[bestStep] + accidentalOffset + 12) % 12
    }

    private func symbol(for accidentalKind: ScoreAccidentalKind) -> String {
        switch accidentalKind {
        case .flat:
            return "♭"
        case .natural:
            return "♮"
        case .sharp:
            return "♯"
        }
    }

    private func title(for accidentalKind: ScoreAccidentalKind) -> String {
        switch accidentalKind {
        case .flat:
            return "降号"
        case .natural:
            return "还原号"
        case .sharp:
            return "升号"
        }
    }
}

enum ScoreReaderMoreNoteTool: Equatable {
    case duration(ScoreNoteDuration)
    case doubleDot
    case grace(ScoreGraceNoteKind)
    /// An engine expression key: an ornament, "arpeggio", a "beam…" mode or a "tremolo…".
    case ornament(String)
    case doubleAccidental(sharp: Bool)
}

struct ScoreReaderMoreNotesOption: Identifiable {
    let title: String
    /// An engine expression key.
    let key: String

    var id: String { key }

    /// Desktop's beam modes for the selected notes.
    static let beamModes = [
        ScoreReaderMoreNotesOption(title: "自动", key: "beamauto"),
        ScoreReaderMoreNotesOption(title: "断开符杠", key: "beambreak"),
        ScoreReaderMoreNotesOption(title: "连接符杠", key: "beamjoin"),
        ScoreReaderMoreNotesOption(title: "无符杠", key: "beamnone")
    ]

    /// Single-note tremolos; choosing the one already on the note removes it.
    static let tremolos = [
        ScoreReaderMoreNotesOption(title: "一道斜杠", key: "tremolo1"),
        ScoreReaderMoreNotesOption(title: "两道斜杠", key: "tremolo2"),
        ScoreReaderMoreNotesOption(title: "三道斜杠", key: "tremolo3")
    ]
}

/// One tool in the More Notes row: a button, or a menu of engine keys when `menu` isn't empty.
struct ScoreReaderMoreNotesItem: Identifiable {
    let id: String
    let glyph: String
    let title: String
    var isSelected = false
    let isEnabled: Bool
    var tool: ScoreReaderMoreNoteTool? = nil
    var menu: [ScoreReaderMoreNotesOption] = []
    /// Bravura glyphs sit at different heights and sizes; these even them out in the button.
    var glyphScale: CGFloat = 1
    var glyphOffset: CGFloat = 0
}

struct ScoreReaderMoreNotesButton: View {
    let item: ScoreReaderMoreNotesItem
    var isCompact = false
    let action: (ScoreReaderMoreNoteTool) -> Void

    var body: some View {
        if item.menu.isEmpty {
            Button {
                if let tool = item.tool {
                    action(tool)
                }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .disabled(!item.isEnabled)
            .opacity(item.isEnabled ? 1 : 0.42)
            .accessibilityLabel(item.title)
        } else {
            Menu {
                ForEach(item.menu) { option in
                    Button(option.title) {
                        action(.ornament(option.key))
                    }
                }
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .disabled(!item.isEnabled)
            .opacity(item.isEnabled ? 1 : 0.42)
            .accessibilityLabel(item.title)
        }
    }

    private var label: some View {
        VStack(spacing: 2) {
            Text(item.glyph)
                .font(MusicNotationFont.font(size: (isCompact ? 21 : (item.glyph.count > 1 ? 21 : 25)) * item.glyphScale))
                .naturalSizeOnAndroid()
                .offset(y: item.glyphOffset)
                .frame(height: isCompact ? 24 : 22)

            Text(item.title)
                .font(.system(size: isCompact ? 8 : 9, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(item.isSelected ? Color.white : Color.black.opacity(0.82))
        .frame(width: isCompact ? 60 : ScoreReaderKeyboardContextToolbar.columnButtonWidth, height: isCompact ? 50 : 48)
        .background(
            item.isSelected ? Color(red: 0.12, green: 0.45, blue: 0.95) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}

struct ScoreReaderContextDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(width: 1, height: 38)
            .padding(.horizontal, 2)
    }
}

struct ScoreReaderTupletMenuButton: View {
    var width: CGFloat = 68
    let isEnabled: Bool
    let action: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(ScoreReaderTupletPreset.allCases) { preset in
                Button(preset.title) {
                    action(preset.count)
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text("3")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 22)

                Text("连音组")
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(width: width, height: 48)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel("连音组")
    }
}

struct ScoreReaderCompactPaletteButton: View {
    var duration: ScoreNoteDuration? = nil
    var textSymbol: String? = nil
    var stackedChordIcon = false
    var usesMusicFont = false
    var width: CGFloat = 46
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let duration {
                    Text(duration.bravuraTextGlyph)
                        .font(MusicNotationFont.font(size: 23))
                } else if stackedChordIcon {
                    Image("ScoreReaderStackedChord")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                } else if let textSymbol {
                    #if os(Android)
                    if AndroidAccidentalGlyph.isAccidental(textSymbol) {
                        AndroidAccidentalGlyph(symbol: textSymbol, size: 26)
                    } else {
                        Text(textSymbol)
                            .font(usesMusicFont ? MusicNotationFont.font(size: 23) : .system(size: 22, weight: .semibold))
                    }
                    #else
                    Text(textSymbol)
                        .font(usesMusicFont ? MusicNotationFont.font(size: 23) : .system(size: 22, weight: .semibold))
                    #endif
                }
            }
            .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.black.opacity(0.82))
            .frame(width: width, height: 46)
            .background(
                isSelected ? Color(red: 0.86, green: 0.93, blue: 1.0) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

struct ScoreReaderCompactControlGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.6)
                .allowsHitTesting(false)
        }
    }
}

struct ScoreReaderCompactGroupedDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.07))
            .frame(width: 0.5, height: 34)
    }
}

struct ScoreReaderCompactGroupedPaletteButton: View {
    var duration: ScoreNoteDuration? = nil
    var textSymbol: String? = nil
    var systemImage: String? = nil
    var stackedChordIcon = false
    var usesMusicFont = false
    var glyphBaselineOffset: CGFloat = 0
    let isSelected: Bool
    let isEnabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let duration {
                    Text(duration.bravuraTextGlyph)
                        .font(MusicNotationFont.font(size: 24))
                } else if stackedChordIcon {
                    Image("ScoreReaderStackedChord")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                } else if let textSymbol {
                    Text(textSymbol)
                        .font(usesMusicFont ? MusicNotationFont.font(size: 23) : .system(size: 22, weight: .semibold))
                        .baselineOffset(glyphBaselineOffset)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.black.opacity(0.82))
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                isSelected ? Color(red: 0.86, green: 0.93, blue: 1.0) : Color.clear,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ScoreReaderCompactGridPaletteButton: View {
    var duration: ScoreNoteDuration? = nil
    var textSymbol: String? = nil
    var systemImage: String? = nil
    var stackedChordIcon = false
    var usesMusicFont = false
    var glyphBaselineOffset: CGFloat = 0
    var musicFontSize: CGFloat = 24
    var glyphVerticalOffset: CGFloat = 0
    let isSelected: Bool
    let isEnabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let duration {
                    Text(duration.bravuraTextGlyph)
                        .font(MusicNotationFont.font(size: 25))
                } else if stackedChordIcon {
                    Image("ScoreReaderStackedChord")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                } else if let textSymbol {
                    #if os(Android)
                    if AndroidAccidentalGlyph.isAccidental(textSymbol) {
                        AndroidAccidentalGlyph(symbol: textSymbol, size: 26)
                    } else {
                        Text(textSymbol)
                            .font(usesMusicFont ? MusicNotationFont.font(size: musicFontSize) : .system(size: 23, weight: .semibold))
                            .baselineOffset(glyphBaselineOffset)
                            .offset(y: glyphVerticalOffset)
                    }
                    #else
                    Text(textSymbol)
                        .font(usesMusicFont ? MusicNotationFont.font(size: musicFontSize) : .system(size: 23, weight: .semibold))
                        .baselineOffset(glyphBaselineOffset)
                        .offset(y: glyphVerticalOffset)
                    #endif
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? Color(red: 0.0, green: 0.48, blue: 1.0) : Color.black.opacity(0.84))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                isSelected ? Color(red: 0.86, green: 0.93, blue: 1.0) : Color.white.opacity(0.58),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.24) : Color.black.opacity(0.08), lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ScoreReaderCompactGridTupletMenuButton: View {
    let isEnabled: Bool
    let action: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(ScoreReaderTupletPreset.allCases) { preset in
                Button(preset.title) {
                    action(preset.count)
                }
            }
        } label: {
            VStack(spacing: 0) {
                Text("3")
                    .font(.system(size: 16, weight: .semibold))
                    .italic()
                    .frame(height: 16)
                HStack(spacing: 0) {
                    Rectangle().frame(width: 1, height: 4)
                    Rectangle().frame(height: 1)
                    Rectangle().frame(width: 1, height: 4)
                }
                .frame(width: 21, height: 6)
            }
            .foregroundStyle(Color.black.opacity(0.84))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel("连音组")
    }
}

struct ScoreReaderCompactTupletMenuButton: View {
    var width: CGFloat = 46
    let isEnabled: Bool
    let action: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(ScoreReaderTupletPreset.allCases) { preset in
                Button(preset.title) {
                    action(preset.count)
                }
            }
        } label: {
            VStack(spacing: 0) {
                Text("3")
                    .font(.system(size: 18, weight: .semibold))
                    .italic()
                    .frame(height: 18)
                HStack(spacing: 0) {
                    Rectangle().frame(width: 1, height: 5)
                    Rectangle().frame(height: 1)
                    Rectangle().frame(width: 1, height: 5)
                }
                .frame(width: 24, height: 7)
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(width: width, height: 46)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel("连音组")
    }
}

enum ScoreReaderTupletPreset: Int, CaseIterable, Identifiable {
    case duplet = 2
    case triplet = 3
    case quadruplet = 4
    case quintuplet = 5
    case sextuplet = 6
    case septuplet = 7
    case octuplet = 8
    case nonuplet = 9

    var id: Int { rawValue }
    var count: Int { rawValue }

    var title: String {
        switch self {
        case .duplet: return "二连音"
        case .triplet: return "三连音"
        case .quadruplet: return "四连音"
        case .quintuplet: return "五连音"
        case .sextuplet: return "六连音"
        case .septuplet: return "七连音"
        case .octuplet: return "八连音"
        case .nonuplet: return "九连音"
        }
    }
}

struct ScoreReaderRepeatContextToolbar: View {
    let isEnabled: Bool
    let addRepeatJumpAction: (String) -> Void

    var body: some View {
        ScoreReaderHorizontalContextToolbar {
            ScoreReaderPaletteButton(textSymbol: "1.", title: "第一结尾", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("First ending") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "2.", title: "第二结尾", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("Second ending") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "||:", title: "反复开始", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("Start repeat") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: ":||", title: "反复结束", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("End repeat") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "D.S.", title: "从记号反复至尾声", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("D.S. al Coda") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "D.S.", title: "从记号反复至结束", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("D.S. al Fine") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "D.C.", title: "从头反复至尾声", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("D.C. al Coda") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "D.C.", title: "从头反复至结束", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("D.C. al Fine") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "\u{E047}", title: "反复记号", usesMusicFont: true, isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("Segno") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "To Coda", title: "跳至尾声", isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("To Coda") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "\u{E048}", title: "尾声", usesMusicFont: true, isSelected: false, isEnabled: isEnabled, action: { addRepeatJumpAction("Coda") })
        }
    }
}

struct ScoreReaderTextContextToolbar: View {
    let isEnabled: Bool
    let addTextAction: (String) -> Void
    let openChordEntryAction: () -> Void
    let openLyricsEntryAction: () -> Void
    let openTempoEditorAction: () -> Void
    let fingeringEnabled: Bool
    let openFingeringAction: () -> Void

    var body: some View {
        ScoreReaderHorizontalContextToolbar {
            ScoreReaderPaletteButton(systemImage: "text.alignleft", title: "谱表文字", isSelected: false, isEnabled: isEnabled, action: { addTextAction("Staff Text") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "text.badge.plus", title: "谱系文字", isSelected: false, isEnabled: isEnabled, action: { addTextAction("System Text") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "A", title: "排练记号", isSelected: false, isEnabled: isEnabled, action: { addTextAction("Rehearsal Mark") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "C7", title: "和弦文字", isSelected: false, isEnabled: isEnabled, action: openChordEntryAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "Ly", title: "歌词", isSelected: false, isEnabled: isEnabled, action: openLyricsEntryAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton.fingering(isEnabled: fingeringEnabled, action: openFingeringAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "metronome", title: "速度", isSelected: false, isEnabled: isEnabled, action: openTempoEditorAction)
        }
    }
}

/// Text > Fingering: a persistent deck so the next note can be tapped on the score.
struct ScoreReaderFingeringPanel: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    let isEnabled: Bool
    let setFingeringAction: (Int) -> Void
    let backAction: () -> Void

    private var isCompact: Bool { AriaWindowLayout.shared.usesPhoneLayout }

    var body: some View {
        VStack(spacing: isCompact ? 14 : 24) {
            HStack {
                Button(action: backAction) {
                    Label("文字", systemImage: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.blue)
                .frame(minWidth: 56, minHeight: 44)

                Spacer()
            }

            HStack(spacing: isCompact ? 8 : 12) {
                // Skip Fuse requires an Int-indexed collection here; ClosedRange
                // has its own Index type and traps in the Android ForEach bridge.
                ForEach([1, 2, 3, 4, 5], id: \.self) { finger in
                    fingeringButton(finger)
                }
                fingeringButton(0)
            }
            .frame(maxWidth: 720)

            if !isEnabled {
                Text("请选择一个音符以添加或移除指法。")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, isCompact ? 4 : 24)
        .padding(.bottom, isCompact ? 4 : 12)
    }

    private func fingeringButton(_ finger: Int) -> some View {
        Button { setFingeringAction(finger) } label: {
            Group {
                if finger == 0 {
                    Image(systemName: "delete.left")
                        .font(.system(size: isCompact ? 24 : 30, weight: .medium))
                } else {
                    Text(String(finger))
                        .font(.system(size: isCompact ? 28 : 36, weight: .semibold))
                }
            }
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: isCompact ? (verticalSizeClass == .compact ? 48 : 64) : 86)
            .background(finger == 0 ? Color.black.opacity(0.05) : Color.white,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 5, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(finger == 0 ? "移除指法" : "指法 \(finger)")
    }
}

struct ScoreReaderExpressionContextToolbar: View {
    let hasSelection: Bool
    let hasNoteSelection: Bool
    let supportsBowingArticulations: Bool
    let addExpressionAction: (String) -> Void

    var body: some View {
        ScoreReaderHorizontalContextToolbar {
            ForEach(Array(ScoreReaderDynamicTools.primary.enumerated()), id: \.element.id) { index, dynamic in
                if index > 0 {
                    ScoreReaderContextDivider()
                }
                ScoreReaderPaletteButton(textSymbol: dynamic.token, title: dynamic.title, isSelected: false, isEnabled: hasSelection, action: { addExpressionAction(dynamic.token) })
            }
            ScoreReaderContextDivider()
            Menu {
                Button("任其延响") {
                    addExpressionAction("LaissezVib")
                }

                ForEach(ScoreReaderDynamicTools.additional) { dynamic in
                    Button(dynamic.title) {
                        addExpressionAction(dynamic.token)
                    }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(height: 22)
                    Text("更多")
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 68, height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection)
            ScoreReaderContextDivider()
            ForEach(ScoreReaderLineTools.primary) { line in
                ScoreReaderPaletteButton(textSymbol: line.symbol, title: line.title, isSelected: false, isEnabled: hasSelection, action: { addExpressionAction(line.token) })
                ScoreReaderContextDivider()
            }
            ScoreReaderLinesMenuButton(isEnabled: hasSelection, addExpressionAction: addExpressionAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(
                textSymbol: ScoreReaderArticulationTools.fermata.symbol,
                title: ScoreReaderArticulationTools.fermata.title,
                usesMusicFont: true,
                isSelected: false,
                isEnabled: hasSelection,
                action: { addExpressionAction(ScoreReaderArticulationTools.fermata.token) }
            )
            ScoreReaderContextDivider()
            ScoreReaderArticulationMenuButton(
                isEnabled: hasNoteSelection,
                supportsBowingArticulations: supportsBowingArticulations,
                addExpressionAction: addExpressionAction
            )
        }
    }
}

struct ScoreReaderLayoutContextToolbar: View {
    let isEnabled: Bool
    let canOpenAutoBreaks: Bool
    let canOpenGlobalLayoutSettings: Bool
    let createMultiMeasureRests: Bool
    let hideEmptyStaves: Bool
    let addLayoutBreakAction: (String) -> Void
    let removeLayoutBreakAction: () -> Void
    let updateLayoutOptionsAction: (ScoreLayoutOptionsValue) -> Void
    let openAutoBreaksAction: () -> Void
    let openInstrumentLayoutAction: () -> Void
    let openPageSettingsAction: () -> Void

    var body: some View {
        ScoreReaderHorizontalContextToolbar {
            ScoreReaderPaletteButton(textSymbol: "----", title: "换行", isSelected: false, isEnabled: isEnabled, action: { addLayoutBreakAction("System Break") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "line.3.horizontal", title: "分页", isSelected: false, isEnabled: isEnabled, action: { addLayoutBreakAction("Page Break") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "link", title: "保持小节同行", isSelected: false, isEnabled: isEnabled, action: { addLayoutBreakAction("Keep Bars Together") })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "lock.rectangle.stack", title: "自动换行与分页", isSelected: false, isEnabled: canOpenAutoBreaks, action: openAutoBreaksAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "M", title: "多小节休止符", isSelected: createMultiMeasureRests, isEnabled: canOpenAutoBreaks, action: {
                updateLayoutOptionsAction(ScoreLayoutOptionsValue(
                    createMultiMeasureRests: !createMultiMeasureRests,
                    hideEmptyStaves: hideEmptyStaves
                ))
            })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "eye.slash", title: "隐藏空谱表", isSelected: hideEmptyStaves, isEnabled: canOpenAutoBreaks, action: {
                updateLayoutOptionsAction(ScoreLayoutOptionsValue(
                    createMultiMeasureRests: createMultiMeasureRests,
                    hideEmptyStaves: !hideEmptyStaves
                ))
            })
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "list.bullet", title: "乐器与谱表", isSelected: false, isEnabled: canOpenGlobalLayoutSettings, action: openInstrumentLayoutAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "doc", title: "页面设置", isSelected: false, isEnabled: canOpenGlobalLayoutSettings, action: openPageSettingsAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "--x--", title: "移除换行或分页", isSelected: false, isEnabled: isEnabled, action: removeLayoutBreakAction)
                .foregroundStyle(Color.red)
        }
    }
}

struct ScoreReaderMoreContextToolbar: View {
    let isEnabled: Bool
    let canFillWithSlashes: Bool
    let canReplaceWithRhythmicSlashes: Bool
    let openAddInstrumentAction: () -> Void
    let openTransposeScoreAction: () -> Void
    let removeSelectedInstrumentAction: () -> Void
    let openClefEditorAction: () -> Void
    let openScoreSetupAction: () -> Void
    let openTempoEditorAction: () -> Void
    let openTimeSignatureAction: () -> Void
    let openKeySignatureAction: () -> Void
    let openPickupMeasureAction: () -> Void
    let fillSelectionWithSlashesAction: () -> Void
    let replaceSelectionWithRhythmicSlashesAction: () -> Void
    let concertPitchEnabled: Bool
    let showsConcertPitchControl: Bool
    let toggleConcertPitchAction: () -> Void

    var body: some View {
        ScoreReaderHorizontalContextToolbar {
            ScoreReaderPaletteButton(systemImage: "slider.horizontal.3", title: "乐谱设置", isSelected: false, isEnabled: isEnabled, action: openScoreSetupAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "music.note.list", title: "添加或移除乐器", isSelected: false, isEnabled: isEnabled, action: openAddInstrumentAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "arrow.up.arrow.down", title: "乐谱移调", isSelected: false, isEnabled: isEnabled, action: openTransposeScoreAction)
            if showsConcertPitchControl {
                ScoreReaderContextDivider()
                ScoreReaderPaletteButton(systemImage: "music.quarternote.3", title: "实音", isSelected: concertPitchEnabled, isEnabled: isEnabled, action: toggleConcertPitchAction)
            }
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "𝄞", title: "更改谱号", isSelected: false, isEnabled: isEnabled, action: openClefEditorAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "♯♭", title: "调号", isSelected: false, isEnabled: isEnabled, action: openKeySignatureAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "4⁄4", title: "拍号", isSelected: false, isEnabled: isEnabled, action: openTimeSignatureAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "metronome", title: "速度", isSelected: false, isEnabled: isEnabled, action: openTempoEditorAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(systemImage: "forward.end", title: "创建弱起小节", isSelected: false, isEnabled: isEnabled, action: openPickupMeasureAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "////", title: "填充斜线记谱", isSelected: false, isEnabled: canFillWithSlashes, action: fillSelectionWithSlashesAction)
            ScoreReaderContextDivider()
            ScoreReaderPaletteButton(textSymbol: "/ /", title: "节奏记谱", isSelected: false, isEnabled: canReplaceWithRhythmicSlashes, action: replaceSelectionWithRhythmicSlashesAction)
        }
    }
}

struct ScoreReaderHorizontalContextToolbar<Content: View>: View {
    @Environment(\.scoreReaderCompactPanelEmbedded) var isEmbeddedInCompactPanel
    @ViewBuilder let content: () -> Content

    var body: some View {
        MobileHintingHorizontalScrollView(hintHeight: isEmbeddedInCompactPanel ? 52 : 58) {
            HStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, isEmbeddedInCompactPanel ? 4 : 10)
            .padding(.vertical, isEmbeddedInCompactPanel ? 4 : 7)
            .frame(minHeight: isEmbeddedInCompactPanel ? 44 : 44)
        }
        .frame(maxWidth: .infinity, minHeight: isEmbeddedInCompactPanel ? 52 : 58)
        .modifier(ScoreReaderHorizontalToolbarChromeModifier(isEmbedded: isEmbeddedInCompactPanel))
    }
}

struct ScoreReaderHorizontalToolbarChromeModifier: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

            content
                .background(Color.white.opacity(0.66), in: shape)
                .overlay {
                    shape
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.7)
                        .allowsHitTesting(false)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 9, y: 2)
        }
    }
}
