import SwiftUI
import PRumoKit

struct RowMenuButton: View {
    let actions: RowActions
    let isLaunching: Bool
    let isRerunning: Bool
    @Binding var menuOpen: Bool

    var body: some View {
        if isLaunching {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(ClaudeMetrics.spinnerScale)
                .frame(width: ClaudeMetrics.menuButtonSize, height: ClaudeMetrics.menuButtonSize)
        } else {
            Menu {
                RowMenuItems(actions: actions, isRerunning: isRerunning)
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
