import SwiftUI

struct ScoreReaderInstrumentReplacementSheet: View {
    @Environment(\.dismiss) var dismiss

    let context: InstrumentReplacementContext
    let isBusy: Bool
    let replaceAction: (NewScoreInstrument, InstrumentReplacementScope) -> Void

    @State var scope: InstrumentReplacementScope
    @State var searchText = ""

    init(
        context: InstrumentReplacementContext,
        isBusy: Bool,
        replaceAction: @escaping (NewScoreInstrument, InstrumentReplacementScope) -> Void
    ) {
        self.context = context
        self.isBusy = isBusy
        self.replaceAction = replaceAction
        _scope = State(initialValue: context.defaultsToMeasureScope ? .fromMeasure : .entireScore)
    }

    private var instruments: [NewScoreInstrument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return NewScoreInstrumentCatalog.importantInstruments
        }
        return NewScoreInstrumentCatalog.importantInstruments.filter {
            $0.name.lowercased().contains(query)
                || $0.instrumentID.lowercased().contains(query)
                || $0.category.rawValue.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if context.tick != nil, let measureIndex = context.measureIndex {
                        Picker("修改范围", selection: $scope) {
                            Text("整首乐谱").tag(InstrumentReplacementScope.entireScore)
                            Text("从第 \(measureIndex + 1) 小节开始").tag(InstrumentReplacementScope.fromMeasure)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    } else {
                        Label("整首乐谱", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("修改范围")
                } footer: {
                    Text(scopeDescription)
                }

                Section {
                    ForEach(instruments) { instrument in
                        Button {
                            replaceAction(instrument, scope)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                CreateScoreClef(clef: instrument.clef, size: 22)
                                    .frame(width: 28, height: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instrument.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(instrument.detailText)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                if instrument.instrumentID == context.currentInstrumentID {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                    }
                } header: {
                    Text("乐器")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("更换 \(context.currentInstrumentName)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索乐器")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var scopeDescription: String {
        switch scope {
        case .entireScore:
            return "Replaces this part's main instrument while preserving its music."
        case .fromMeasure:
            guard let measureIndex = context.measureIndex else {
                return "Select a measure to make an instrument change."
            }
            return "Creates or updates an instrument change beginning at measure \(measureIndex + 1)."
        }
    }
}
