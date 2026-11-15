// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct CloudLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var cloud: CloudLibraryModel
    let addToLibrary: (URL) async throws -> Void
    let openLocal: (URL) -> Void
    @State private var detail: CloudScore?
    private var scrollPosition: Binding<AnyHashable?> {
        Binding(get: { cloud.scrollID.map(AnyHashable.init) }, set: { cloud.scrollID = $0?.base as? String })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("分类", selection: $cloud.filter) {
                    Text("全部").tag("all"); Text("MSCZ").tag("mscz")
                    Text("MIDI").tag("mid"); Text("PDF").tag("pdf"); Text("已下载").tag("saved")
                }.pickerStyle(.segmented).padding()
                if let message = cloud.message { Text(message).font(.footnote).padding(.horizontal).accessibilityLabel(message) }
                if cloud.refreshing && cloud.catalog == nil { ProgressView("正在读取云端曲库…").padding() }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(cloud.scores) { score in
                            Button { detail = score } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: score.format == "pdf" ? "doc" : "music.note.list").frame(width: 32)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(verbatim: score.name).lineLimit(2)
                                        Text("\(score.format.uppercased()) · \(ByteCountFormatter.string(fromByteCount: Int64(score.size), countStyle: .file))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if cloud.isSaved(score) { Image(systemName: "checkmark.circle").accessibilityLabel("已保存到本地") }
                                    Image(systemName: "chevron.right").font(.caption)
                                }.padding().contentShape(Rectangle())
                            }.buttonStyle(.plain).id(AnyHashable(score.id))
                            Divider()
                        }
                        if cloud.scores.isEmpty && !cloud.refreshing { Text("暂无符合条件的曲谱").foregroundStyle(.secondary).padding(36) }
                    }.scrollTargetLayout()
                }.scrollPosition(id: scrollPosition)
            }
            .navigationTitle("云端曲库")
            .searchable(text: $cloud.query, prompt: "搜索曲名")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { Task { await cloud.refresh() } } label: { Image(systemName: "arrow.clockwise") }.disabled(cloud.refreshing) }
            }
            .task { cloud.updateLocalFiles(); await cloud.refresh() }
            .sheet(item: $detail) { score in
                NavigationStack {
                    Form {
                        Section("曲谱详情") {
                            Text(verbatim: score.name)
                            LabeledContent("格式", value: score.format.uppercased())
                            LabeledContent("大小", value: ByteCountFormatter.string(fromByteCount: Int64(score.size), countStyle: .file))
                            Text(verbatim: score.path).font(.caption).textSelection(.enabled)
                        }
                        Section {
                            if cloud.isSaved(score) {
                                Label("已保存到本地", systemImage: "checkmark.circle")
                                Button(score.format == "pdf" ? "查看 PDF 并识别为可播放曲谱" : "导入本地乐谱") {
                                    guard let url = try? CloudScoreService.fileURL(score) else { return }
                                    detail = nil; dismiss(); openLocal(url)
                                }
                            } else if cloud.savingID == score.id {
                                ProgressView("正在下载并校验…")
                                Button("取消下载", role: .cancel) { cloud.cancelDownload() }
                            } else {
                                Button("保存到本地") { cloud.save(score, addToLibrary: addToLibrary) }.disabled(cloud.savingID != nil)
                            }
                            if let message = cloud.message { Text(message).font(.footnote) }
                        } footer: { Text("曲库只读。曲谱先保存到本地，再导入、看谱或编辑；本地修改不会上传。") }
                    }.navigationTitle("曲谱详情")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回") { detail = nil } } }
                }
            }
        }
    }
}
