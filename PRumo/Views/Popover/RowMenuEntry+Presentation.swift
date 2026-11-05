import SwiftUI
import AppKit
import PRumoKit

extension RowMenuEntry {
    var title: String {
        switch self {
        case .claude(let purpose, _): purpose.menuTitle
        case .openInBrowser: RowMenuText.openInBrowser
        case .openJira(let key, _): RowMenuText.openJira(key)
        case .rerunFailedJobs(let jobName, _): RowMenuText.rerunFailedJobs(jobName)
        case .copyLink: RowMenuText.copyLink
        case .copyCheckout(let command, _): RowMenuText.copyCheckout(command)
        case .separator: ""
        case .pin(let isPinned): isPinned ? RowMenuText.unpin : RowMenuText.pin
        case .mute(let isMuted): isMuted ? RowMenuText.unmute : RowMenuText.mute
        }
    }

    var help: String? {
        if case .copyCheckout(_, let warning) = self { return warning }
        return nil
    }

    var keyboardShortcut: KeyboardShortcut? {
        switch self {
        case .claude(_, let primary):
            primary ? KeyboardShortcut(KeyEquivalent(Character(ClaudeText.shortcutKey)), modifiers: .command) : nil
        case .openJira: KeyboardShortcut(KeyEquivalent(RowMenuKey.openJira), modifiers: .command)
        case .copyLink: KeyboardShortcut(KeyEquivalent(RowMenuKey.copy), modifiers: .command)
        case .copyCheckout: KeyboardShortcut(KeyEquivalent(RowMenuKey.copy), modifiers: [.command, .shift])
        case .openInBrowser, .rerunFailedJobs, .separator, .pin, .mute: nil
        }
    }

    var menuKeyEquivalent: String {
        keyboardShortcut.map { String($0.key.character) } ?? ""
    }

    var menuKeyModifiers: NSEvent.ModifierFlags {
        guard let modifiers = keyboardShortcut?.modifiers else { return [] }
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        return flags
    }
}
