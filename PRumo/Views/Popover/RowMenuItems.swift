import SwiftUI
import AppKit
import PRumoKit

struct RowMenuItems: View {
    let pr: PullRequest
    let actions: RowActions

    private static let shortcut = KeyboardShortcut(KeyEquivalent(Character(ClaudeText.shortcutKey)), modifiers: .command)

    var body: some View {
        if !actions.claudePurposes.isEmpty {
            ForEach(Array(actions.claudePurposes.enumerated()), id: \.offset) { index, purpose in
                Button {
                    actions.launch(purpose)
                } label: {
                    Label {
                        Text(purpose.menuTitle)
                    } icon: {
                        Image(nsImage: ClaudeMarkImage.menuIcon)
                    }
                }
                .keyboardShortcut(index == 0 ? Self.shortcut : nil)
            }
            Divider()
        }
        Button(ClaudeText.openInBrowser) {
            NSWorkspace.shared.open(pr.url)
        }
        Button(ClaudeText.copyLink) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pr.url.absoluteString, forType: .string)
        }
    }
}
