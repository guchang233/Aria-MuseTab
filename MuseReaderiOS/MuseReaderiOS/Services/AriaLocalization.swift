// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Translate catalog labels only. Engine IDs, filenames and user score titles stay intact.
enum AriaLocalization {
    nonisolated private static let translations: [String: String] = {
        guard let url = AppResources.url(forResource: "ChineseNotation", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return values
    }()
    nonisolated static func text(_ value: String) -> String { translations[value] ?? value }
}
