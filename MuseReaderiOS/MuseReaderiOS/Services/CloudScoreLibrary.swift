// SPDX-License-Identifier: GPL-3.0-or-later
// Static GitHub catalog. No REST API, credentials, uploads, or remote edits.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CloudScore: Codable, Identifiable, Hashable, Sendable {
    let path: String
    let size: Int
    let sha: String
    var id: String { path + ":" + sha }
    var name: String { URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }
    var format: String { path.components(separatedBy: "/")[0].lowercased() }
}

struct CloudCatalog: Codable, Sendable {
    let version: Int
    let repo: String
    let branch: String
    let commit: String
    let updatedAt: Double
    let scores: [CloudScore]

    nonisolated func validated() throws -> CloudCatalog {
        guard version == 1, repo == CloudScoreService.repository,
              GitBlobHash.isHash(commit), updatedAt.isFinite, scores.count <= 50_000 else {
            throw CloudScoreError.message("曲库清单版本或内容不正确")
        }
        var paths = Set<String>()
        for score in scores {
            let parts = score.path.components(separatedBy: "/")
            let ext = URL(fileURLWithPath: score.path).pathExtension.lowercased()
            guard parts.count >= 2, !score.path.contains("\\"),
                  !score.path.contains("\0"), parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  ["mid", "mscz", "pdf"].contains(score.format),
                  ext == score.format || (score.format == "mid" && ext == "midi"),
                  score.size > 0, GitBlobHash.isHash(score.sha), paths.insert(score.path).inserted else {
                throw CloudScoreError.message("曲库中存在无效或重复的文件信息")
            }
        }
        return self
    }
}

enum CloudScoreError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

enum CloudScoreService {
    nonisolated static let repository = "guchang233/muse-repo"
    nonisolated static let maxFileSize = 32 * 1024 * 1024

    nonisolated static func root() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("CloudScores", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    nonisolated static func fileURL(_ score: CloudScore) throws -> URL {
        // Each immutable revision has its own directory; retain the human-readable filename.
        try root().appendingPathComponent(score.sha.lowercased(), isDirectory: true)
            .appendingPathComponent(URL(fileURLWithPath: score.path).lastPathComponent)
    }

    nonisolated static func fetchCatalog() async throws -> CloudCatalog {
        let url = URL(string: "https://raw.githubusercontent.com/\(repository)/main/catalog.json")!
        let data = try await download(url, maximum: 4 * 1024 * 1024, timeout: 45)
        return try JSONDecoder().decode(CloudCatalog.self, from: data).validated()
    }

    nonisolated static func save(_ score: CloudScore, commit: String) async throws -> URL {
        guard GitBlobHash.isHash(commit), score.size <= maxFileSize else {
            throw CloudScoreError.message("曲谱超过 32 MB，暂不支持保存")
        }
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "%?#/"))
        let path = score.path.components(separatedBy: "/").map { $0.addingPercentEncoding(withAllowedCharacters: allowed)! }.joined(separator: "/")
        let url = URL(string: "https://raw.githubusercontent.com/\(repository)/\(commit)/\(path)")!
        let data = try await download(url, maximum: maxFileSize, timeout: 120)
        let matches = await Task.detached(priority: .utility) {
            data.count == score.size && GitBlobHash.hash(data) == score.sha.lowercased()
        }.value
        guard matches else {
            throw CloudScoreError.message("下载校验失败，请刷新曲库后重试")
        }
        let header = Array(data.prefix(5))
        let valid = score.format == "pdf" ? header == Array("%PDF-".utf8)
            : score.format == "mid" ? Array(header.prefix(4)) == Array("MThd".utf8)
            : Array(header.prefix(2)) == [80, 75]
        guard valid else { throw CloudScoreError.message("文件内容与后缀不符，或上传的是 Git LFS 指针") }
        try Task.checkCancellation()
        let target = try fileURL(score)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
        return target
    }

    nonisolated private static func download(_ url: URL, maximum: Int, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("Aria-MuseTab", forHTTPHeaderField: "User-Agent")
        // URLSession downloads to disk; reject oversized content before reading it into memory.
        let (temporary, response) = try await URLSession.shared.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CloudScoreError.message((response as? HTTPURLResponse)?.statusCode == 404
                ? "曲库文件尚未发布，请稍后刷新" : "曲库服务暂时不可用，请稍后重试")
        }
        let bytes = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0, bytes <= maximum else { throw CloudScoreError.message("曲库文件为空或超过大小限制") }
        try Task.checkCancellation()
        return try Data(contentsOf: temporary)
    }
}

// Git object identity is SHA-1("blob <length>\0" + bytes), not SHA-1(bytes).
// Kept independent of CryptoKit because Aria's Android shim only exposes SHA-256.
enum GitBlobHash {
    nonisolated static func isHash(_ value: String) -> Bool {
        value.utf8.count == 40 && value.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }
    }
    nonisolated static func hash(_ data: Data) -> String {
        var bytes = Array("blob \(data.count)\0".utf8) + data
        let length = UInt64(bytes.count) * 8
        bytes.append(128)
        while bytes.count % 64 != 56 { bytes.append(0) }
        bytes += (0..<8).reversed().map { UInt8(truncatingIfNeeded: length >> ($0 * 8)) }
        var h: [UInt32] = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0]
        func rotate(_ n: UInt32, _ bits: UInt32) -> UInt32 { (n << bits) | (n >> (32 - bits)) }
        for start in stride(from: 0, to: bytes.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 80)
            for i in 0..<16 { let j = start + i * 4; w[i] = UInt32(bytes[j]) << 24 | UInt32(bytes[j+1]) << 16 | UInt32(bytes[j+2]) << 8 | UInt32(bytes[j+3]) }
            for i in 16..<80 { w[i] = rotate(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1) }
            var a=h[0], b=h[1], c=h[2], d=h[3], e=h[4]
            for i in 0..<80 {
                let f: UInt32, k: UInt32
                switch i { case 0..<20: f=(b & c) | (~b & d); k=0x5a827999
                case 20..<40: f=b ^ c ^ d; k=0x6ed9eba1
                case 40..<60: f=(b & c) | (b & d) | (c & d); k=0x8f1bbcdc
                default: f=b ^ c ^ d; k=0xca62c1d6 }
                let next = rotate(a,5) &+ f &+ e &+ k &+ w[i]
                e=d; d=c; c=rotate(b,30); b=a; a=next
            }
            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d; h[4] = h[4] &+ e
        }
        return h.map { String(format: "%08x", $0) }.joined()
    }
}
