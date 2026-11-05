import SwiftUI
import PRumoKit

struct RowMenuItems: View {
    let actions: RowActions
    let isRerunning: Bool

    var body: some View {
        ForEach(Array(actions.entries.enumerated()), id: \.offset) { _, entry in
            item(entry)
        }
    }

    @ViewBuilder
    private func item(_ entry: RowMenuEntry) -> some View {
        switch entry {
        case .separator:
            Divider()
        case .claude:
            Button {
                actions.perform(entry)
            } label: {
                Label {
                    Text(entry.title)
                } icon: {
                    Image(nsImage: ClaudeMarkImage.menuIcon)
                }
            }
            .keyboardShortcut(entry.keyboardShortcut)
        case .rerunFailedJobs(_, _, let disabledReason), .cancelAndRerun(let disabledReason):
            Button(entry.title) { actions.perform(entry) }
                .disabled(isRerunning || disabledReason != nil)
                .help(entry.help ?? "")
        default:
            Button(entry.title) { actions.perform(entry) }
                .keyboardShortcut(entry.keyboardShortcut)
                .help(entry.help ?? "")
        }
    }
}
