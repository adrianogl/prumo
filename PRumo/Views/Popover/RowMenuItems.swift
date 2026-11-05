import SwiftUI
import AppKit
import PRumoKit

struct RowMenuItems: View {
    let pr: PullRequest
    let actions: RowActions

    var body: some View {
        if let purpose = actions.claudePurpose {
            Button {
                actions.launch(purpose)
            } label: {
                Label {
                    Text(purpose == .review ? ClaudeText.review : ClaudeText.fixCI)
                } icon: {
                    Image(nsImage: ClaudeMarkImage.menuIcon)
                }
            }
            .keyboardShortcut(KeyEquivalent(Character(ClaudeText.shortcutKey)), modifiers: .command)
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
