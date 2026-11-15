// Run on a host with Swift: swiftc <CloudScoreLibrary.swift> checks/CloudScoreChecks.swift -o .local/cloud-check
import Foundation

@main struct CloudScoreChecks {
    static func main() async throws {
        precondition(GitBlobHash.hash(Data()) == "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
        precondition(GitBlobHash.hash(Data("hello\n".utf8)) == "ce013625030ba8dba906f756967f9e9ca394464a")
        precondition(!GitBlobHash.isHash(String(repeating: "z", count: 40)))
        let score = CloudScore(path: "mscz/中文 乐谱.mscz", size: 100, sha: String(repeating: "a", count: 40))
        let valid = CloudCatalog(version: 1, repo: "guchang233/muse-repo", branch: "main",
                                commit: String(repeating: "b", count: 40), updatedAt: 1, scores: [score])
        _ = try valid.validated()
        for path in ["mscz/../bad.mscz", "pdf/bad.mscz", "mscz//bad.mscz", "mscz\\bad.mscz"] {
            let bad = CloudScore(path: path, size: 100, sha: score.sha)
            let catalog = CloudCatalog(version: 1, repo: valid.repo, branch: "main", commit: valid.commit,
                                       updatedAt: 1, scores: [bad])
            do { _ = try catalog.validated(); fatalError("Invalid path accepted: \(path)") } catch {}
        }
        print("Cloud catalog and Git blob hash checks passed")
    }
}
