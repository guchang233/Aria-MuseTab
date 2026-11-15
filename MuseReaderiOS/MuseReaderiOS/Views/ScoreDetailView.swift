//
//  ScoreDetailView.swift
//  MuseReaderiOS
//
//

import SwiftUI
import UIKit

struct ScoreDetailView: View {
    var model: MuseReaderAppModel
    let session: ScoreSession

    @State var readerPresentation: ReaderPresentation?
    @State var exportedMIDIFile: SharedExportFile?
    @State var exportErrorMessage: String?
    @State var isPreparingMIDIExport = false
    @State var editableMetadata = ScoreEditableMetadata()
    @State var isEditingMetadataPresented = false
    @State var isSavingMetadata = false
    @State var metadataSaveErrorMessage: String?

    private var canOpenReader: Bool {
        session.pageCount > 0
    }

    private var canExportPlaybackMIDI: Bool {
        session.capabilities.supportsPlayback && session.liveRenderSession != nil
    }

    private var canEditMetadata: Bool {
        session.capabilities.supportsEditing && session.liveRenderSession != nil
    }

    var body: some View {
        contentView
            .sheet(item: $exportedMIDIFile, content: shareSheet)
            .sheet(isPresented: $isEditingMetadataPresented, content: metadataEditorSheet)
            .alert("播放数据导出失败", isPresented: exportErrorIsPresented, actions: exportErrorActions, message: exportErrorMessageView)
            .alert("无法保存乐谱信息", isPresented: metadataSaveErrorIsPresented, actions: metadataSaveErrorActions, message: metadataSaveErrorMessageView)
    }

    private var contentView: some View {
        SwiftUI.ScrollView(.vertical, showsIndicators: true) {
            detailSections
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.96, blue: 0.93),
                    Color(red: 0.91, green: 0.89, blue: 0.84)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationTitle(session.document.primaryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $readerPresentation) { presentation in
            ScoreReaderView(session: session, initialPageIndex: presentation.startPageIndex)
        }
    }

    private var detailSections: some View {
        VStack(alignment: .leading, spacing: 28) {
            ScoreHeroSection(
                session: session,
                openReaderAction: canOpenReader ? { openReader(at: session.coverPage?.index ?? 0) } : nil,
                editInfoAction: canEditMetadata ? { presentMetadataEditor() } : nil,
                exportMIDIAction: canExportPlaybackMIDI ? { exportPlaybackMIDI() } : nil,
                isSavingMetadata: isSavingMetadata,
                isPreparingMIDIExport: isPreparingMIDIExport
            )

            ScorePreviewStripSection(
                session: session,
                openPageAction: { pageIndex in
                    openReader(at: pageIndex)
                }
            )

            ScoreCapabilitiesSection(session: session)
            ScoreMetadataSection(
                document: session.document,
                editInfoAction: canEditMetadata ? { presentMetadataEditor() } : nil
            )
            ScorePackageContentsSection(entries: session.document.packageEntries)
            ScoreSourceSection(excerpt: session.document.scoreExcerpt)
        }
        .padding(28)
    }

    private func shareSheet(for export: SharedExportFile) -> some View {
        ShareSheetView(activityItems: [export.url])
    }

    private func exportErrorActions() -> some View {
        Button("确定", role: .cancel) {}
    }

    private func exportErrorMessageView() -> some View {
        Text(exportErrorMessage ?? "无法为此乐谱导出 MIDI。")
    }

    private func openReader(at pageIndex: Int) {
        guard canOpenReader else {
            return
        }

        readerPresentation = ReaderPresentation(startPageIndex: pageIndex)
    }

    private func exportPlaybackMIDI() {
        guard let liveRenderSession = session.liveRenderSession, !isPreparingMIDIExport else {
            return
        }

        isPreparingMIDIExport = true
        exportErrorMessage = nil

        Task {
            do {
                let midiData = try await liveRenderSession.playbackMIDIData()
                let exportedURL = try Self.writePlaybackMIDIFile(
                    midiData,
                    preferredBaseName: session.document.primaryTitle
                )

                await MainActor.run {
                    exportedMIDIFile = SharedExportFile(url: exportedURL)
                    isPreparingMIDIExport = false
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isPreparingMIDIExport = false
                }
            }
        }
    }

    private func presentMetadataEditor() {
        Task {
            // An open score's document still has the metadata it was opened with.
            if let liveRenderSession = session.liveRenderSession {
                editableMetadata = await liveRenderSession.currentMetadata()
            } else {
                editableMetadata = ScoreEditableMetadata(document: session.document)
            }
            metadataSaveErrorMessage = nil
            isEditingMetadataPresented = true
        }
    }

    private func saveEditedMetadata() {
        guard canEditMetadata, !isSavingMetadata else {
            return
        }

        isSavingMetadata = true
        metadataSaveErrorMessage = nil
        let metadataToSave = editableMetadata

        Task {
            do {
                try await model.saveMetadata(metadataToSave, for: session)
                await MainActor.run {
                    isSavingMetadata = false
                    isEditingMetadataPresented = false
                }
            } catch {
                await MainActor.run {
                    metadataSaveErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isSavingMetadata = false
                }
            }
        }
    }

    private var exportErrorIsPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    exportErrorMessage = nil
                }
            }
        )
    }

    private var metadataSaveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { metadataSaveErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    metadataSaveErrorMessage = nil
                }
            }
        )
    }

    private func metadataSaveErrorActions() -> some View {
        Button("确定", role: .cancel) {}
    }

    private func metadataSaveErrorMessageView() -> some View {
        Text(metadataSaveErrorMessage ?? "无法保存这些乐谱信息。")
    }

    private func metadataEditorSheet() -> some View {
        NavigationStack {
            Form {
                Section("标题页") {
                    TextField("标题", text: $editableMetadata.title)
                    TextField("副标题", text: $editableMetadata.subtitle)
                }

                Section("署名") {
                    TextField("作曲", text: $editableMetadata.composer)
                    TextField("编曲", text: $editableMetadata.arranger)
                    TextField("作词", text: $editableMetadata.lyricist)
                }

                Section {
                    Text("这些修改会保存到本地导入副本，并重新打开乐谱。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("编辑乐谱信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isEditingMetadataPresented = false
                    }
                    .disabled(isSavingMetadata)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSavingMetadata ? "正在保存…" : "保存") {
                        saveEditedMetadata()
                    }
                    .disabled(isSavingMetadata)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private static func writePlaybackMIDIFile(_ midiData: Data, preferredBaseName: String) throws -> URL {
        let sanitizedBaseName = preferredBaseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyOrFallback("Aria Export")

        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AriaExports", isDirectory: true)

        try FileManager.default.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let exportURL = exportDirectory.appendingPathComponent("\(sanitizedBaseName).mid")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }

        try midiData.write(to: exportURL, options: .atomic)
        return exportURL
    }
}

enum ScoreDetailPalette {
    static let accent = Color(red: 0.75, green: 0.28, blue: 0.19)
    static let accentSoft = Color(red: 0.96, green: 0.91, blue: 0.86)
    static let ink = Color(red: 0.18, green: 0.13, blue: 0.09)
    static let mutedInk = Color(red: 0.40, green: 0.31, blue: 0.22)
}

struct ScoreHeroSection: View {
    let session: ScoreSession
    let openReaderAction: (() -> Void)?
    let editInfoAction: (() -> Void)?
    let exportMIDIAction: (() -> Void)?
    let isSavingMetadata: Bool
    let isPreparingMIDIExport: Bool

    private var heroImage: UIImage? {
        session.coverPage?.rasterizedImage() ?? session.document.previewImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ScoreHeroChip(text: session.document.format.rawValue.uppercased(), symbol: "music.note.list")
                    ScoreHeroChip(text: session.renderPipeline.summaryLabel, symbol: "sparkles.rectangle.stack")

                    if let version = session.document.museScoreVersion?.trimmedToNil {
                        ScoreHeroChip(text: "MuseScore \(version)", symbol: "music.note")
                    }
                }

                Text(session.document.primaryTitle)
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(ScoreDetailPalette.ink)

                if let subtitle = session.document.subtitle?.trimmedToNil {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(ScoreDetailPalette.mutedInk)
                }

                Text(session.renderPipeline.detailText)
                    .font(.body)
                    .foregroundStyle(ScoreDetailPalette.mutedInk)
                    .frame(maxWidth: 560, alignment: .leading)

                HStack(spacing: 16) {
                    ScoreHeroMetric(value: "\(session.pageCount)", label: session.pageCount == 1 ? "页" : "页")
                    ScoreHeroMetric(value: "\(session.document.partCount)", label: session.document.partCount == 1 ? "声部" : "声部")
                    ScoreHeroMetric(value: session.capabilities.supportsLivePageRendering ? "Live" : "Preview", label: "渲染路径")
                }

                if openReaderAction != nil || editInfoAction != nil || exportMIDIAction != nil {
                    HStack(spacing: 12) {
                        if let openReaderAction {
                            Button("打开看谱", systemImage: "arrow.up.left.and.arrow.down.right", action: openReaderAction)
                                .buttonStyle(.borderedProminent)
                                .tint(ScoreDetailPalette.accent)
                        }

                        if let editInfoAction {
                            Button(action: editInfoAction) {
                                if isSavingMetadata {
                                    Label("正在保存信息", systemImage: "square.and.pencil")
                                } else {
                                    Label("编辑信息", systemImage: "square.and.pencil")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(ScoreDetailPalette.accent)
                            .disabled(isSavingMetadata)
                        }

                        if let exportMIDIAction {
                            Button(action: exportMIDIAction) {
                                if isPreparingMIDIExport {
                                    Label("正在准备 MIDI", systemImage: "arrow.down.circle")
                                } else {
                                    Label("导出 MIDI", systemImage: "square.and.arrow.up")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(ScoreDetailPalette.accent)
                            .disabled(isPreparingMIDIExport)
                        }
                    }
                    .padding(.top, 6)
                }
            }

            Spacer(minLength: 0)

            ScoreHeroCover(image: heroImage, format: session.document.format)
                .frame(width: 290)
        }
        .padding(28)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
    }
}

struct ScoreHeroChip: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ScoreDetailPalette.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(ScoreDetailPalette.accentSoft, in: Capsule())
    }
}

struct ScoreHeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(ScoreDetailPalette.ink)
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 88, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ScoreHeroCover: View {
    let image: UIImage?
    let format: ScoreFileFormat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Color(red: 0.93, green: 0.89, blue: 0.82))
                            .frame(width: 112, height: 116)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(ScoreDetailPalette.accent)
                            }

                        ForEach(0..<6, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(Color.black.opacity(index == 0 ? 0.10 : 0.06))
                                .frame(width: index.isMultiple(of: 2) ? 180 : 150, height: 8)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.97, blue: 0.94),
                                Color(red: 0.93, green: 0.90, blue: 0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text(format.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(ScoreDetailPalette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(ScoreDetailPalette.accentSoft, in: Capsule())
                .padding(18)
        }
        .aspectRatio(0.74, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 10)
    }
}

struct ScorePreviewStripSection: View {
    let session: ScoreSession
    let openPageAction: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeadingView(title: "乐谱页面")

            if session.previewPages.isEmpty {
                LiveRenderingCallout(
                    title: session.pageCount > 0 ? "实时看谱已就绪" : "暂无可用页面",
                    detail: session.pageCount > 0
                        ? "此乐谱没有预览缓存，仍可打开并实时生成谱面。"
                        : session.renderPipeline.detailText,
                    buttonTitle: session.pageCount > 0 ? "打开看谱" : nil,
                    buttonAction: session.pageCount > 0 ? { openPageAction(0) } : nil
                )
            } else {
                MobileHintingHorizontalScrollView(hintHeight: 46) {
                    HStack(spacing: 18) {
                        ForEach(session.previewPages) { page in
                            ScorePreviewCard(
                                page: page,
                                openAction: { openPageAction(page.index) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct ScorePreviewCard: View {
    let page: ScorePage
    let openAction: () -> Void

    var body: some View {
        Button(action: openAction) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)

                    if let image = page.rasterizedImage() {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white)
                            .overlay {
                                VStack(spacing: 10) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 28, weight: .light))
                                    Text(page.title)
                                        .font(.headline)
                                }
                                .foregroundStyle(ScoreDetailPalette.mutedInk)
                            }
                    }

                    Text("第 \(page.index + 1) 页")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.94), in: Capsule())
                        .padding(14)
                }
                .frame(width: 240, height: 320)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(page.source.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ScoreDetailPalette.ink)

                    Text("在看谱中打开此页")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LiveRenderingCallout: View {
    let title: String
    let detail: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.title3)
                    .foregroundStyle(ScoreDetailPalette.accent)

                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ScoreDetailPalette.ink)
            }

            Text(detail)
                .font(.body)
                .foregroundStyle(ScoreDetailPalette.mutedInk)

            if let buttonTitle, let buttonAction {
                Button(buttonTitle, systemImage: "arrow.up.left.and.arrow.down.right", action: buttonAction)
                    .buttonStyle(.borderedProminent)
                    .tint(ScoreDetailPalette.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct ScoreCapabilitiesSection: View {
    let session: ScoreSession

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadingView(title: "当前乐谱支持的功能")

            LazyVGrid(columns: columns, spacing: 16) {
                CapabilityCard(
                    title: "文件包检查",
                    isAvailable: session.capabilities.supportsPackageInspection,
                    detail: "Aria 直接读取 MuseScore 文件包与 XML，包括乐谱信息、主谱、文件条目和内嵌预览。"
                )

                CapabilityCard(
                    title: "实时排谱",
                    isAvailable: session.capabilities.supportsLivePageRendering,
                    detail: session.capabilities.supportsLivePageRendering
                        ? "页面由 MuseScore 排谱核心按需生成。"
                        : "实时排谱就绪前，此乐谱仅能显示内嵌预览。"
                )

                CapabilityCard(
                    title: "播放",
                    isAvailable: session.capabilities.supportsPlayback,
                    detail: session.capabilities.supportsPlayback
                        ? "通过 MuseScore 播放事件与原生音频输出，可以直接播放当前乐谱。"
                        : "计划功能：核心接口就绪后，将接入当前乐谱播放。"
                )

                CapabilityCard(
                    title: "编辑",
                    isAvailable: session.capabilities.supportsEditing,
                    detail: session.capabilities.supportsEditing
                        ? "可在当前 MuseScore 乐谱会话中修改并保存乐谱信息。"
                        : "计划功能：在看谱稳定后，为当前乐谱接入编辑与保存。"
                )
            }
        }
    }
}

struct ScoreMetadataSection: View {
    let document: ScoreDocument
    let editInfoAction: (() -> Void)?

    private let columns = [
        GridItem(.adaptive(minimum: 220), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                SectionHeadingView(title: "乐谱摘要")

                Spacer(minLength: 0)

                if let editInfoAction {
                    Button("编辑信息", systemImage: "square.and.pencil", action: editInfoAction)
                        .buttonStyle(.bordered)
                        .tint(ScoreDetailPalette.accent)
                }
            }

            LazyVGrid(columns: columns, spacing: 16) {
                MetadataCard(title: "作曲", value: document.composer)
                MetadataCard(title: "作词", value: document.lyricist)
                MetadataCard(title: "编曲", value: document.arranger)
                MetadataCard(title: "声部", value: "\(document.partCount)")
                MetadataCard(title: "主乐谱文件", value: document.rootFilePath)
                MetadataCard(title: "文件大小", value: formattedFileSize)
                MetadataCard(title: "修改时间", value: formattedDate)
                MetadataCard(title: "文件包条目", value: "\(document.packageEntries.count)")
            }
        }
    }

    private var formattedFileSize: String? {
        guard let fileSize = document.fileSize else {
            return nil
        }

        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    private var formattedDate: String? {
        guard let modificationDate = document.modificationDate else {
            return nil
        }

        return modificationDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct ScorePackageContentsSection: View {
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadingView(title: "文件包内容")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries.prefix(30), id: \.self) { entry in
                    Text(entry)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                if entries.count > 30 {
                    Text("另有 \(entries.count - 30) 项")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

struct ScoreSourceSection: View {
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeadingView(title: "XML 摘要")

            Text(excerpt)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .foregroundStyle(Color.white.opacity(0.92))
        }
    }
}

struct SectionHeadingView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.title2, design: .serif).weight(.bold))
            .foregroundStyle(ScoreDetailPalette.ink)
    }
}

struct MetadataCard: View {
    let title: String
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(value?.trimmedToNil ?? "—")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct CapabilityCard: View {
    let title: String
    let isAvailable: Bool
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                    .foregroundStyle(isAvailable ? Color.green : Color.orange)
            }
            .font(.headline)

            Text(isAvailable ? "可用" : "计划中")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ReaderPresentation: Identifiable {
    let startPageIndex: Int

    var id: Int {
        startPageIndex
    }
}

struct SharedExportFile: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

private extension String {
    func nonEmptyOrFallback(_ fallback: String) -> String {
        trimmedToNil ?? fallback
    }
}
