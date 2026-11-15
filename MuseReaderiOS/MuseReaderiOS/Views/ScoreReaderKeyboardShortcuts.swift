//
//  ScoreReaderKeyboardShortcuts.swift
//  MuseReaderiOS
//

import SwiftUI
import UIKit

struct ScoreReaderKeyboardShortcutView: UIViewRepresentable {
    var isEnabled: Bool
    var action: (ScoreReaderKeyboardShortcut) -> Void

    func makeUIView(context: Context) -> KeyboardShortcutHostingView {
        let view = KeyboardShortcutHostingView()
        view.isEnabled = isEnabled
        view.action = action
        return view
    }

    func updateUIView(_ uiView: KeyboardShortcutHostingView, context: Context) {
        uiView.isEnabled = isEnabled
        uiView.action = action
        uiView.refreshFirstResponder()
    }
}

final class KeyboardShortcutHostingView: UIView {
    var isEnabled = true {
        didSet {
            refreshFirstResponder()
        }
    }
    var action: ((ScoreReaderKeyboardShortcut) -> Void)?

    override var canBecomeFirstResponder: Bool {
        isEnabled
    }

    override var keyCommands: [UIKeyCommand]? {
        guard isEnabled else {
            return nil
        }

        return [
            command("z", modifiers: .command, title: "撤销"),
            command("z", modifiers: [.command, .shift], title: "重做"),
            command("y", modifiers: .command, title: "重做"),
            command("c", modifiers: .command, title: "复制"),
            command("x", modifiers: .command, title: "剪切"),
            command("v", modifiers: .command, title: "粘贴"),
            command("a", modifiers: .command, title: "全选"),
            command(UIKeyCommand.inputDelete, title: "删除"),
            command(" ", title: "播放或暂停"),
            command(UIKeyCommand.inputEscape, title: "清除选区"),
            command("n", title: "切换音符输入"),
            command("a", title: "输入 A"),
            command("b", title: "输入 B"),
            command("c", title: "输入 C"),
            command("d", title: "输入 D"),
            command("e", title: "输入 E"),
            command("f", title: "输入 F"),
            command("g", title: "输入 G"),
            command("0", title: "输入休止符"),
            command("3", title: "十六分音符"),
            command("4", title: "八分音符"),
            command("5", title: "四分音符"),
            command("6", title: "二分音符"),
            command("7", title: "全音符"),
            command(".", title: "切换附点"),
            command("+", title: "延音线"),
            command("=", modifiers: .shift, title: "延音线"),
            command("s", title: "连音线"),
            command("1", modifiers: .command, title: "声部 1"),
            command("2", modifiers: .command, title: "声部 2"),
            command("3", modifiers: .command, title: "声部 3"),
            command("4", modifiers: .command, title: "声部 4"),
            command(UIKeyCommand.inputLeftArrow, title: "上一个元素"),
            command(UIKeyCommand.inputUpArrow, title: "升高音高"),
            command(UIKeyCommand.inputRightArrow, title: "下一个元素"),
            command(UIKeyCommand.inputDownArrow, title: "降低音高"),
            command(UIKeyCommand.inputUpArrow, modifiers: .alternate, title: "升高八度"),
            command(UIKeyCommand.inputDownArrow, modifiers: .alternate, title: "降低八度"),
            command(UIKeyCommand.inputUpArrow, modifiers: .command, title: "升高半音"),
            command(UIKeyCommand.inputDownArrow, modifiers: .command, title: "降低半音"),
            command(UIKeyCommand.inputUpArrow, modifiers: .shift, title: "升高半音"),
            command(UIKeyCommand.inputDownArrow, modifiers: .shift, title: "降低半音"),
            command(UIKeyCommand.inputPageUp, title: "上一页"),
            command(UIKeyCommand.inputPageDown, title: "下一页")
        ]
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshFirstResponder()
    }

    func refreshFirstResponder() {
        guard window != nil else {
            return
        }

        if isEnabled {
            DispatchQueue.main.async { [weak self] in
                _ = self?.becomeFirstResponder()
            }
        } else if isFirstResponder {
            resignFirstResponder()
        }
    }

    @objc private func performShortcut(_ sender: UIKeyCommand) {
        guard let shortcut = Self.resolveShortcut(input: sender.input ?? "", modifiers: sender.modifierFlags)
        else {
            return
        }

        action?(shortcut)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard isEnabled else {
            super.pressesBegan(presses, with: event)
            return
        }

        let shortcuts = presses.compactMap(shortcut(for:))
        guard !shortcuts.isEmpty else {
            super.pressesBegan(presses, with: event)
            return
        }

        shortcuts.forEach { action?($0) }
    }

    private func command(
        _ input: String,
        modifiers: UIKeyModifierFlags = [],
        title: String
    ) -> UIKeyCommand {
        UIKeyCommand(
            input: input,
            modifierFlags: modifiers,
            action: #selector(performShortcut(_:)),
            discoverabilityTitle: title
        )
    }

    static func resolveShortcut(input: String, modifiers: UIKeyModifierFlags) -> ScoreReaderKeyboardShortcut? {
        let key: ScoreReaderShortcutKey
        switch input {
        case UIKeyCommand.inputDelete: key = .delete
        case UIKeyCommand.inputEscape: key = .escape
        case UIKeyCommand.inputLeftArrow: key = .leftArrow
        case UIKeyCommand.inputRightArrow: key = .rightArrow
        case UIKeyCommand.inputUpArrow: key = .upArrow
        case UIKeyCommand.inputDownArrow: key = .downArrow
        case UIKeyCommand.inputPageUp: key = .pageUp
        case UIKeyCommand.inputPageDown: key = .pageDown
        default: key = .character(input)
        }
        return ScoreReaderKeyboardShortcut.resolve(key, modifiers: Self.modifiers(modifiers))
    }

    private static func modifiers(_ flags: UIKeyModifierFlags) -> ScoreReaderShortcutModifiers {
        var modifiers: ScoreReaderShortcutModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.alternate) { modifiers.insert(.alternate) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }

    /// Keys whose presses arrive outside key commands: Command-1...4, the arrows and Page Up/Down.
    private func shortcut(for press: UIPress) -> ScoreReaderKeyboardShortcut? {
        guard let key = press.key else {
            return nil
        }

        let shortcutKey: ScoreReaderShortcutKey
        switch key.keyCode {
        case .keyboard1: shortcutKey = .character("1")
        case .keyboard2: shortcutKey = .character("2")
        case .keyboard3: shortcutKey = .character("3")
        case .keyboard4: shortcutKey = .character("4")
        case .keyboardLeftArrow: shortcutKey = .leftArrow
        case .keyboardRightArrow: shortcutKey = .rightArrow
        case .keyboardUpArrow: shortcutKey = .upArrow
        case .keyboardDownArrow: shortcutKey = .downArrow
        case .keyboardPageUp: shortcutKey = .pageUp
        case .keyboardPageDown: shortcutKey = .pageDown
        default: return nil
        }
        let modifiers = Self.modifiers(key.modifierFlags)
        // Digits only with Command (voices); plain digits are durations, sent as key commands.
        if case .character = shortcutKey, modifiers != .command {
            return nil
        }
        return ScoreReaderKeyboardShortcut.resolve(shortcutKey, modifiers: modifiers)
    }
}
