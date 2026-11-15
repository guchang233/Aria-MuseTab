//
//  ScoreExportModels.swift
//  MuseReaderiOS
//
//  Export formats, requests and errors, kept apart from the export panel and
//  exporters (UIKit, AVFoundation, PDFKit).
//

import Foundation
import SwiftUI

enum ScoreReaderExportFormat: String, CaseIterable, Identifiable {
    case museScore
    case pdf
    case musicXML
    case midi
    case audio
    case images
    case video

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .museScore:
            return ".mscz"
        case .pdf:
            return "PDF"
        case .musicXML:
            return "MusicXML"
        case .midi:
            return "MIDI"
        case .audio:
            return "音频"
        case .images:
            return "图片"
        case .video:
            return "视频"
        }
    }

    var subtitle: String {
        switch self {
        case .museScore:
            return "MuseScore 原生文件"
        case .pdf:
            return "适合分享与打印"
        case .musicXML:
            return ".musicxml or .xml"
        case .midi:
            return "用于播放或音频工作站的 .mid 文件"
        case .audio:
            return ".wav"
        case .images:
            return "PNG 页面图片"
        case .video:
            return "滚动乐谱或钢琴画面"
        }
    }

    var systemImage: String {
        switch self {
        case .museScore:
            return "doc.badge.gearshape"
        case .pdf:
            return "doc.richtext"
        case .musicXML:
            return "doc.text"
        case .midi:
            return "music.note"
        case .audio:
            return "waveform"
        case .images:
            return "photo.on.rectangle"
        case .video:
            return "play.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .museScore:
            return Color.gray
        case .pdf:
            return Color.red
        case .musicXML:
            return Color.gray
        case .midi:
            return Color.purple
        case .audio:
            return Color.green
        case .images:
            return Color.blue
        case .video:
            return Color.orange
        }
    }

    var isAvailable: Bool {
        switch self {
        case .museScore, .pdf, .musicXML, .midi, .audio, .images, .video:
            return true
        }
    }

    var exportsDisplayedView: Bool {
        switch self {
        case .pdf, .images, .video:
            return true
        case .museScore, .musicXML, .midi, .audio:
            return false
        }
    }
}

struct ScoreReaderExportDraft {
    var includesFullScore = true
    var includesParts = false
    var format: ScoreReaderExportFormat = .pdf
    var selectedPartIDs: Set<String> = []
    var fileName = ""
    var exportPartsInConcertPitch = false
    var exportPartsInOriginalKey = false
    var videoStyle: ScoreVideoStyle = .scrolling
    /// 9:16 for Reels and TikTok, for every layout (Pages uses its portrait style).
    var videoVertical = false
    var videoBackgroundImageData: Data? = nil
    var videoBackgroundImageName: String? = nil
    /// The built-in photo in use (`ScoreVideoBackgroundPhoto.id`), or nil for
    /// the person's own.
    var videoBackgroundPhotoID: String? = nil
    /// The person's own photo, kept while a built-in one is chosen.
    var videoCustomBackgroundData: Data? = nil

    var hasExportContent: Bool {
        includesFullScore || includesParts
    }
}

struct ScoreReaderSharedExportItems: Identifiable {
    let urls: [URL]

    var id: String {
        urls.map(\.absoluteString).joined(separator: "|")
    }
}

enum ScoreReaderExportError: LocalizedError {
    case unsupportedFormat(String)
    case noContentSelected
    case noPages
    case noAudio
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "当前核心暂不支持导出 \(format)。"
        case .noContentSelected:
            return "请至少选择一个导出对象。"
        case .noPages:
            return "没有可导出的谱面。"
        case .noAudio:
            return "没有可导出的播放音频。"
        case .imageEncodingFailed:
            return "某个乐谱页面无法编码为图片。"
        }
    }
}

enum ScoreReaderExportTarget {
    case fullScore(pageCount: Int)
    case part(ScorePart, pageCount: Int)

    var pageCount: Int {
        switch self {
        case .fullScore(let pageCount), .part(_, let pageCount):
            return pageCount
        }
    }
}

struct ScoreVideoBackgroundPhoto: Identifiable, Sendable {
    /// The file name in Resources/VideoBackgrounds, without ".jpg".
    let id: String
    let name: String

    static let all: [ScoreVideoBackgroundPhoto] = [
        ScoreVideoBackgroundPhoto(id: "mount-fuji", name: "富士山"),
        ScoreVideoBackgroundPhoto(id: "grand-canyon", name: "大峡谷"),
        ScoreVideoBackgroundPhoto(id: "moonlit-fjord", name: "月下峡湾"),
        ScoreVideoBackgroundPhoto(id: "spruce-forest", name: "云杉林"),
        ScoreVideoBackgroundPhoto(id: "misty-mountains", name: "雾中群山"),
        ScoreVideoBackgroundPhoto(id: "northern-lights", name: "极光"),
        ScoreVideoBackgroundPhoto(id: "mountain-sunset", name: "山间落日"),
        ScoreVideoBackgroundPhoto(id: "snowy-peaks", name: "雪峰"),
        ScoreVideoBackgroundPhoto(id: "pink-bay", name: "粉色海湾"),
        ScoreVideoBackgroundPhoto(id: "beach-sunset", name: "海滩落日"),
        ScoreVideoBackgroundPhoto(id: "forest-river", name: "林间河流"),
        ScoreVideoBackgroundPhoto(id: "beech-ferns", name: "山毛榉与蕨类"),
        ScoreVideoBackgroundPhoto(id: "blue-sky", name: "蓝天")
    ]

    var url: URL? {
        AppResources.url(forResource: id, withExtension: "jpg")
            ?? AppResources.url(forResource: id, withExtension: "jpg", subdirectory: "VideoBackgrounds")
    }
}

extension ScoreReaderExportFormat {
    /// The formats a whole setlist can be shared as. MIDI, audio, and page
    /// images stay with single-score export, where the reader can still offer
    /// the part and page choices those formats depend on.
    static let setlistShareFormats: [ScoreReaderExportFormat] = [.pdf, .museScore, .musicXML]

    var setlistFileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .museScore:
            return "mscz"
        case .musicXML:
            return "musicxml"
        case .midi:
            return "mid"
        case .audio:
            return "wav"
        case .images:
            return "png"
        case .video:
            return "mp4"
        }
    }
}

struct SetlistShareFailure: Identifiable {
    let id = UUID()
    let scoreTitle: String
    let message: String
}

struct SetlistSharePreparation {
    let urls: [URL]
    let failures: [SetlistShareFailure]
}

enum SetlistShareError: LocalizedError {
    case emptySetlist
    case unsupportedFormat(String)
    case unavailableScore(String)
    case pdfMergeFailed
    case noSharableScores(String?)

    var errorDescription: String? {
        switch self {
        case .emptySetlist:
            return "请先向曲目单添加乐谱，再进行分享。"
        case .unsupportedFormat(let format):
            return "曲目单暂不支持以 \(format) 格式分享。"
        case .unavailableScore(let scoreTitle):
            return "无法打开“\(scoreTitle)”，请先打开此乐谱，再重试。"
        case .pdfMergeFailed:
            return "无法将这些乐谱合并为一个 PDF。"
        case .noSharableScores(let reason):
            let summary = "无法准备此曲目单中的乐谱。"
            guard let reason else {
                return summary
            }
            return "\(summary) \(reason)"
        }
    }
}
