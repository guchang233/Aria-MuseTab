// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Observation
#if os(Android)
import SkipFuse
#endif

@MainActor @Observable final class CloudLibraryModel {
    var catalog: CloudCatalog?
    var filter = "all"
    var query = ""
    var scrollID: String?
    var refreshing = false
    var savingID: String?
    var message: String?
    var localFiles = Set<String>()
    private var downloadTask: Task<Void, Never>?

    init() {
        if let root = try? CloudScoreService.root(),
           let data = try? Data(contentsOf: root.appendingPathComponent("catalog.json")),
           let value = try? JSONDecoder().decode(CloudCatalog.self, from: data).validated() { catalog = value }
        updateLocalFiles()
    }
    var scores: [CloudScore] {
        (catalog?.scores ?? []).filter {
            (filter == "all" || $0.format == filter || (filter == "saved" && isSaved($0)))
            && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func isSaved(_ score: CloudScore) -> Bool {
        localFiles.contains(score.sha.lowercased() + "/" + URL(fileURLWithPath: score.path).lastPathComponent)
    }
    func updateLocalFiles() {
        guard let root = try? CloudScoreService.root() else { return }
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? []
        localFiles = Set(files.filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map { $0.deletingLastPathComponent().lastPathComponent + "/" + $0.lastPathComponent })
    }
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true; message = nil
        defer { refreshing = false }
        do {
            let value = try await CloudScoreService.fetchCatalog()
            if let root = try? CloudScoreService.root() { try JSONEncoder().encode(value).write(to: root.appendingPathComponent("catalog.json"), options: .atomic) }
            catalog = value
        } catch is CancellationError {} catch { message = "刷新失败：\(error.localizedDescription)。缓存曲库仍可浏览。" }
    }
    func save(_ score: CloudScore, addToLibrary: @escaping (URL) async throws -> Void) {
        guard savingID == nil, !isSaved(score), let commit = catalog?.commit else { return }
        savingID = score.id; message = nil
        downloadTask = Task {
            defer { savingID = nil; downloadTask = nil }
            do {
                let url = try await CloudScoreService.save(score, commit: commit)
                if score.format == "mscz" { try await addToLibrary(url) }
                updateLocalFiles(); message = "已保存到本地"
            }
            catch is CancellationError { message = "下载已取消" }
            catch { updateLocalFiles(); message = error.localizedDescription }
        }
    }
    func cancelDownload() { downloadTask?.cancel() }
}
