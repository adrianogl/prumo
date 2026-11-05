import SwiftUI
import AppKit
import PRumoKit

extension PullRequest {
    var hasFailedCI: Bool {
        if case .failure = ci { return true }
        return false
    }
}

struct RowActions {
    let claudePurpose: SessionPurpose?
    let launch: (SessionPurpose) -> Void
}

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
                    Image(ClaudeSymbol.mark).renderingMode(.original)
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

struct RowMenuButton: View {
    let pr: PullRequest
    let actions: RowActions
    let isLaunching: Bool

    var body: some View {
        if isLaunching {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(ClaudeMetrics.spinnerScale)
                .frame(width: ClaudeMetrics.menuButtonSize, height: ClaudeMetrics.menuButtonSize)
        } else {
            Menu {
                RowMenuItems(pr: pr, actions: actions)
            } label: {
                Image(systemName: ClaudeSymbol.more)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: ClaudeMetrics.menuButtonSize, height: ClaudeMetrics.menuButtonSize)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help(ClaudeText.moreActions)
        }
    }
}
