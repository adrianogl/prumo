import SwiftUI
import PRumoKit

struct RowMenuButton: View {
    let pr: PullRequest
    let actions: RowActions
    let isLaunching: Bool
    @Binding var menuOpen: Bool

    var body: some View {
        if isLaunching {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(ClaudeMetrics.spinnerScale)
                .frame(width: ClaudeMetrics.menuButtonSize, height: ClaudeMetrics.menuButtonSize)
        } else {
            Menu {
                RowMenuItems(pr: pr, actions: actions)
                    .onAppear { menuOpen = true }
                    .onDisappear { menuOpen = false }
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
            .accessibilityLabel(ClaudeText.moreActions)
        }
    }
}
