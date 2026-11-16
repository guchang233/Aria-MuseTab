// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PlayableConversionView: View {
    @Environment(\.dismiss) var dismiss
    let model: MuseReaderAppModel
    let initialSource: URL?
    @State var source: URL?
    @State var pageRange = "1"
    @State var picking = false
    @State var running = false
    @State var phase = ""
    @State var progress = 0.0
    @State var results: [URL] = []
    @State var task: Task<Void, Never>?
    @State var savedPDFs: [URL] = []
    @State var showsOriginal = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let source { Text(verbatim: source.lastPathComponent) }
                    Button("选择本地 PDF 或 MIDI") { picking = true }.disabled(running)
                    if source?.pathExtension.lowercased() == "pdf" {
                        Button("查看原始 PDF") { showsOriginal = true }
                        TextField("页码，如 1、1-3、1,3；全部填 all", text: $pageRange).disabled(running)
                    }
                } header: {
                    Text("源文件")
                } footer: {
                    Text("全部在设备内完成，无需上传。原始文件会保留；识别后请校对音高、节奏和声部。")
                }
                Section {
                    if running {
                        ProgressView(value: progress)
                        Text(phase)
                        Button("取消识别", role: .cancel) { task?.cancel() }
                    } else {
                        Button("转换为可播放曲谱") { start() }.disabled(source == nil)
                        if !phase.isEmpty { Text(phase).font(.footnote) }
                    }
                    if !results.isEmpty {
                        Button("校对并播放") {
                            let first = results[0]
                            dismiss()
                            model.handleImport(result: .success(first))
                        }
                        Text("结果已保存为 MSCZ 并加入本地乐谱。原 PDF 与转换结果分别保留。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !savedPDFs.isEmpty {
                    Section("已保存的 PDF") {
                        ForEach(savedPDFs, id: \.path) { url in
                            Button(url.lastPathComponent) { source = url; results = []; phase = "" }.disabled(running)
                        }
                    }
                }
            }
            .navigationTitle("PDF 与 MIDI 转换")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { task?.cancel(); dismiss() } } }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf, .midi]) { result in
                do {
                    let input = try result.get()
                    let access = input.startAccessingSecurityScopedResource()
                    defer { if access { input.stopAccessingSecurityScopedResource() } }
                    let folder = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                        appropriateFor: nil, create: true).appendingPathComponent("PDFSources/\(UUID().uuidString)", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let target = folder.appendingPathComponent(input.lastPathComponent)
                    try FileManager.default.copyItem(at: input, to: target)
                    source = target; results = []; phase = ""; loadSavedPDFs()
                } catch { phase = error.localizedDescription }
            }
            .onAppear { source = initialSource ?? source; loadSavedPDFs() }
            .sheet(isPresented: $showsOriginal) { if let source { OriginalPDFView(url: source) } }
            .onDisappear { task?.cancel() }
        }
    }
    private func loadSavedPDFs() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let roots = [documents?.appendingPathComponent("PDFSources"), try? CloudScoreService.root()].compactMap { $0 }
        savedPDFs = roots.flatMap { root in
            (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
                .filter { $0.pathExtension.lowercased() == "pdf" }
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    private func start() {
        guard let source, !running else { return }
        running = true; results = []; progress = 0; phase = "正在启动离线识别…"
        task = Task {
            defer { running = false; task = nil }
            do {
                let xml = try await PlayableConversion.run(source: source, pages: pageRange) { state in
                    phase = state.message; progress = state.progress
                }
                phase = "正在由 MuseScore 排谱并保存 MSCZ…"
                results = try await model.addConvertedScores(xml)
                phase = "转换完成，请打开结果进行校对。"
            } catch is CancellationError { phase = "已取消，原文件保持完整" }
            catch { phase = error.localizedDescription }
        }
    }
}
