// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import UIKit
#if os(Android)
import SkipFuse
#else
import PDFKit
#endif

struct OriginalPDFView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var page = 0
    @State private var count = 0
    @State private var image: UIImage?
    @State private var error = ""
    @State private var loading = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if loading { ProgressView("正在加载页面…") }
                if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity) }
                if !error.isEmpty { Text(error).foregroundStyle(.secondary) }
                HStack(spacing: 24) {
                    Button("上一页") { page -= 1 }.disabled(page == 0 || loading)
                    Text("第 \(page + 1)/\(count) 页")
                    Button("下一页") { page += 1 }.disabled(page + 1 >= count || loading)
                }.padding()
            }.navigationTitle("原始 PDF")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
            .task(id: page) { await render() }
        }
    }
    private func render() async {
        loading = true; error = ""
        defer { loading = false }
        do {
            #if os(Android)
            let path = url.path, index = page
            let result = try await Task.detached(priority: .userInitiated) { () -> (String, Int) in
                let bridge = try AnyDynamicObject(className: "aria.skip.AriaConversion")
                let count: Int = try bridge.pdfPageCount(path)
                let file: String = try bridge.pdfPreview(path, index)
                return (file, count)
            }.value
            try Task.checkCancellation()
            count = result.1; image = UIImage(contentsOfFile: result.0)
            #else
            guard let document = PDFDocument(url: url), let item = document.page(at: page) else {
                throw CloudScoreError.message("无法读取此 PDF 页面")
            }
            count = document.pageCount
            image = item.thumbnail(of: CGSize(width: 1600, height: 2200), for: .mediaBox)
            #endif
        } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
}
