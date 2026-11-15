//
//  OpenSourceLegalView.swift
//  MuseReaderiOS
//
//

import SwiftUI

struct OpenSourceLegalView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LegalSection(title: "Aria") {
                        Text("Aria 包含源自 MuseScore Studio 的记谱、排谱、MusicXML、播放及渲染核心代码。MuseScore Studio 采用 GNU 通用公共许可证第 3 版。")
                        Text("对应版本的源码随本应用的公开源码发布提供。")
                        Link(destination: URL(string: "https://github.com/guchang233/Aria-MuseTab")!) {
                            Label("本版本完整源码", systemImage: "arrow.up.right.square")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        Link("Aria 上游源码", destination: URL(string: "https://github.com/hdi200/aria")!)
                        Text("在法律允许的范围内，本程序不提供任何担保。")
                    }

                    LegalSection(title: "核心许可证") {
                        LegalNoticeRow(name: "Andromr / homr 离线曲谱识别", detail: "AGPL-3.0；源码及许可证随本项目提供")
                        LegalNoticeRow(name: "Chaquopy / LiteRT / ONNX Runtime", detail: "对应许可证及来源见随附的第三方声明")
                        LegalNoticeRow(name: "MuseScore Studio", detail: "GPLv3")
                        LegalNoticeRow(name: "Qt Framework", detail: "此版本适用的许可条款见随附 Qt 声明")
                        LegalNoticeRow(name: "FluidSynth", detail: "LGPL 2.1")
                        LegalNoticeRow(name: "FreeType", detail: "FreeType 许可证或兼容 GPL 的许可选项")
                        LegalNoticeRow(name: "Opus", detail: "BSD 类许可证")
                        LegalNoticeRow(name: "BravuraText", detail: "SIL 开放字体许可证 1.1")
                        LegalNoticeRow(name: "MuseScore General 音色库", detail: "根据音色库内嵌元数据采用 MIT 许可证")
                    }

                    LegalSection(title: "Qt 框架声明") {
                        Text("Aria 使用 Qt 库与工具构建，适用条款取决于发布版本使用的具体 Qt 发行版。")
                        Text("发布源码包包含对应的 Qt 声明及适用许可证全文。")
                        Link(destination: URL(string: "https://www.qt.io/licensing")!) {
                            Label("Qt 许可信息", systemImage: "arrow.up.right.square")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                    }

                    LegalSection(title: "随附文件") {
                        Text("许可证全文及第三方声明位于应用资源的 Legal 目录中，并随源码发布提供。")
                    }
                }
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("开源信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LegalSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LegalNoticeRow: View {
    let name: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            Text(detail)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}
