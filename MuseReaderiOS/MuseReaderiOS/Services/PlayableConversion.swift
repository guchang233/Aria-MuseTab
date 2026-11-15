// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
#if os(Android)
import SkipFuse
#endif

struct ConversionStatus: Decodable, Sendable {
    let state: String
    let message: String
    let progress: Double
    var outputs: [String]?
}

enum PlayableConversion {
    static func run(source: URL, pages: String,
                    progress: @escaping @MainActor (ConversionStatus) -> Void) async throws -> [URL] {
        #if os(Android)
        let worker = try AnyDynamicObject(className: "aria.skip.AriaConversion")
        let job: String = try worker.start(source.path, pages)
        let statusURL = URL(fileURLWithPath: job).appendingPathComponent("status.json")
        let heartbeatURL = URL(fileURLWithPath: job).appendingPathComponent("heartbeat")
        do {
            while true {
                try Task.checkCancellation()
                if let data = try? Data(contentsOf: statusURL),
                   let state = try? JSONDecoder().decode(ConversionStatus.self, from: data) {
                    await progress(state)
                    if state.state == "done" {
                        let outputs = (state.outputs ?? []).map { URL(fileURLWithPath: $0) }
                        guard !outputs.isEmpty else { throw CloudScoreError.message("转换没有返回曲谱") }
                        return outputs
                    }
                    if state.state == "error" || state.state == "cancelled" { throw CloudScoreError.message(state.message) }
                }
                if let lastBeat = try? heartbeatURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   Date().timeIntervalSince(lastBeat) > 60 {
                    throw CloudScoreError.message("识别进程已停止响应，请重试。原始文件已保留。")
                }
                try await Task.sleep(for: .milliseconds(250))
            }
        } catch {
            let _: Void? = try? worker.cancel(job)
            throw error
        }
        #else
        throw CloudScoreError.message("离线 PDF 识别目前集成于 Android 版；此平台可导入转换后的 MusicXML 或 MSCZ。")
        #endif
    }
}
