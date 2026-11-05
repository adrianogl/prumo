import SwiftUI
import PRumoKit

extension RowMenuEntry {
    var title: String {
        switch self {
        case .claude(let purpose, _): purpose.menuTitle
        case .openInBrowser: RowMenuText.openInBrowser
        case .openJira(let key, _): RowMenuText.openJira(key)
        case .rerunFailedJobs(let jobName, _): RowMenuText.rerunFailedJobs(jobName)
        case .copyLink: RowMenuText.copyLink
        case .copyCheckout(let command): RowMenuText.copyCheckout(command)
        case .separator: ""
        case .pin(let isPinned): isPinned ? RowMenuText.unpin : RowMenuText.pin
        case .mute(let isMuted): isMuted ? RowMenuText.unmute : RowMenuText.mute
        }
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
}
