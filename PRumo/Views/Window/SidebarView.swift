import SwiftUI
import PRumoKit

struct SidebarView: View {
    let tabCounts: [ListTab: Int]
    let views: [SavedView]
    let repositories: [RepositoryCount]
    let sessions: [TerminalSessionInfo]
    let focusedSession: UUID?
    let selectSession: (TerminalSessionInfo) -> Void
    @Binding var tab: ListTab
    @Binding var scope: SidebarScope

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Wordmark(size: MainWindowMetrics.wordmarkSize)
                    .padding(.horizontal, 10)
                    .padding(.top, MainWindowMetrics.sidebarTopInset)
                    .padding(.bottom, 14)
                    .accessibilityLabel(MainWindowText.title)
                tabRow(.mine, title: PopoverText.mineTab)
                tabRow(.review, title: PopoverText.reviewTab)
                tabRow(.merge, title: PopoverText.mergeTab)
                if !views.isEmpty {
                    header(MainWindowText.views)
                    ForEach(views) { view in
                        scopeRow(.view(view.id), title: view.name, count: nil, help: nil)
                    }
                }
                header(MainWindowText.repositories)
                scopeRow(.all, title: MainWindowText.allRepositories, count: nil, help: nil)
                ForEach(repositories) { repository in
                    scopeRow(
                        .repository(repository.key), title: RepositoryName.short(repository.key),
                        count: repository.count, help: repository.displayName)
                }
                if !sessions.isEmpty {
                    header(MainWindowText.sessions)
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .background(Color.windowSidebar)
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .padding(.bottom, 4)
    }

    private func tabRow(_ target: ListTab, title: String) -> some View {
        let isSelected = tab == target
        let count = tabCounts[target] ?? 0
        return Button {
            tab = target
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(count > 0 ? Color.white : Color.secondary)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(count > 0 ? Color.prumoCaramel : Color.windowLine, in: Capsule())
            }
            .sidebarRow(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func scopeRow(_ target: SidebarScope, title: String, count: Int?, help: String?) -> some View {
        let isSelected = scope == target
        return Button {
            scope = target
        } label: {
            HStack {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if let count {
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .sidebarRow(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .help(help ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sessionRow(_ session: TerminalSessionInfo) -> some View {
        Button {
            selectSession(session)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(session.status.color)
                    .frame(width: MainWindowMetrics.sessionDotSize, height: MainWindowMetrics.sessionDotSize)
                Text(TerminalText.tabTitle(session))
                    .lineLimit(1)
                Spacer()
            }
            .sidebarRow(isSelected: focusedSession == session.id)
        }
        .buttonStyle(.plain)
        .help(session.status.label)
    }
}

private extension View {
    func sidebarRow(isSelected: Bool) -> some View {
        font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.prumoCaramel : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.prumoCaramel.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}
