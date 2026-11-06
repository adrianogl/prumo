import SwiftUI
import PRumoKit

struct MainWindowView: View {
    let model: AppModel
    @State private var tab: ListTab = .mine
    @State private var scope: SidebarScope = .all
    @State private var selectedID: String?
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isApplyingRequest = false

    private var organization: OrganizationStore { model.organization }
    private var terminals: TerminalSessionStore { model.terminals }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var filter: RowFilter {
        let base = organization.settings.filter
        switch scope {
        case .all:
            return base
        case .view(let id):
            return organization.settings.views.first { $0.id == id }?.filter ?? base
        case .repository(let key):
            var scoped = base
            scoped.repositories = [key]
            return scoped
        }
    }

    private func listing(_ tab: ListTab) -> PullRequestListing {
        PullRequestListing(model: model, tab: tab)
    }

    private func items(for tab: ListTab, now: Date) -> [PullRequest] {
        listing(tab).sections(filter: filter, query: trimmedQuery, highlighted: [], now: now).flatMap(\.items)
    }

    private var selectedPullRequest: PullRequest? {
        guard let selectedID else { return nil }
        return items(for: tab, now: .now).first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                tabCounts: Dictionary(uniqueKeysWithValues: ListTab.allCases.map { ($0, items(for: $0, now: .now).count) }),
                views: organization.settings.views,
                repositories: SidebarCounts.repositories(listing(tab).source()),
                sessions: terminals.registry.sessions,
                focusedSession: terminals.registry.focusedID,
                selectSession: selectSession,
                tab: $tab, scope: $scope)
                .navigationSplitViewColumnWidth(
                    min: MainWindowMetrics.sidebarMinWidth, ideal: MainWindowMetrics.sidebarIdealWidth)
                .toolbar(removing: .sidebarToggle)
        } content: {
            list
                .navigationSplitViewColumnWidth(
                    min: MainWindowMetrics.listMinWidth, ideal: MainWindowMetrics.listIdealWidth)
        } detail: {
            VSplitView {
                detail
                    .frame(minHeight: TerminalMetrics.detailMinHeight)
                if terminals.isPanelVisible, !terminals.registry.sessions.isEmpty {
                    TerminalPanel(store: terminals, select: selectSession)
                        .frame(idealHeight: TerminalMetrics.panelIdealHeight)
                }
            }
            .frame(minWidth: MainWindowMetrics.detailMinWidth)
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar(removing: .title)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background(Color.prumoPopoverBackground)
        .frame(minWidth: MainWindowMetrics.minWidth, minHeight: MainWindowMetrics.minHeight)
        .background { shortcuts }
        .onAppear { model.mainWindow.didOpen() }
        .onDisappear { model.mainWindow.didClose() }
        .onChange(of: model.reviewBadgeCount, initial: true) { _, count in
            DockBadge.update(count: count)
        }
        .onChange(of: tab) { if !isApplyingRequest { selectedID = nil } }
        .onChange(of: scope) { if !isApplyingRequest { selectedID = nil } }
        .onChange(of: selectedID) { _, id in
            if let id { terminals.focus(pullRequest: id) }
        }
        .onChange(of: model.windowFocusRequest, initial: true) { _, id in
            guard let id else { return }
            reveal(pullRequest: id)
            model.windowFocusRequest = nil
        }
    }

    private var list: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let prs = items(for: tab, now: context.date)
            VStack(alignment: .leading, spacing: 0) {
                Text(tabTitle)
                    .font(.system(size: MainWindowMetrics.listTitleSize, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.top, MainWindowMetrics.sidebarTopInset)
                searchField
                if prs.isEmpty {
                    ContentUnavailableView(emptyText, systemImage: MainWindowSymbol.repository)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(prs, selection: $selectedID) { pr in
                        CompactRowView(
                            presentation: listing(tab).presentation(for: pr, now: context.date),
                            age: RelativeAge.string(from: pr.updatedAt, now: context.date),
                            reference: pr.reference,
                            repository: RepositoryName.short(pr.repositoryKey),
                            isStale: listing(tab).staleSince(accountID: pr.accountID).isStale,
                            isNew: organization.unseen.contains(pr.id),
                            session: terminals.registry.session(forPullRequest: pr.id)?.status)
                            .tag(pr.id)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedID == pr.id ? Color.prumoCaramel.opacity(0.2) : Color.clear)
                                    .padding(.horizontal, 4))
                            .listRowSeparatorTint(Color.windowLine)
                            .onAppear { organization.markSeen([pr.id]) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.windowCard, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.windowLine))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .background(Color.prumoPopoverBackground)
        }
    }

    private var searchField: some View {
        HStack(spacing: PopoverMetrics.searchSpacing) {
            Image(systemName: PopoverSymbol.search)
                .foregroundStyle(.secondary)
            TextField(MainWindowText.searchPrompt, text: $query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onExitCommand { query = "" }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, PopoverMetrics.searchVerticalPadding)
        .padding(.vertical, 2)
        .background(Color.windowCard, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.windowLine))
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var detail: some View {
        if let pr = selectedPullRequest {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                PullRequestDetailView(
                    pr: pr,
                    presentation: listing(tab).presentation(for: pr, now: context.date),
                    entries: listing(tab).menuEntries(for: pr, now: context.date),
                    now: context.date,
                    isLaunching: model.isLaunching(pr),
                    perform: { model.perform($0, on: pr) })
            }
        } else {
            ContentUnavailableView(
                MainWindowText.noSelection, systemImage: MainWindowSymbol.open,
                description: Text(MainWindowText.noSelectionHint))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.prumoPopoverBackground)
        }
    }

    private var tabTitle: String {
        switch tab {
        case .mine: PopoverText.mineTab
        case .review: PopoverText.reviewTab
        case .merge: PopoverText.mergeTab
        }
    }

    private var emptyText: String {
        if !trimmedQuery.isEmpty { return PopoverText.nothingFound(query: trimmedQuery) }
        return switch tab {
        case .mine: PopoverText.emptyMine
        case .review: PopoverText.emptyReview
        case .merge: PopoverText.emptyMerge
        }
    }

    private var shortcuts: some View {
        Group {
            Button("") { tab = .mine }.keyboardShortcut(MainWindowKey.mine, modifiers: .command)
            Button("") { tab = .review }.keyboardShortcut(MainWindowKey.review, modifiers: .command)
            Button("") { tab = .merge }.keyboardShortcut(MainWindowKey.merge, modifiers: .command)
            Button("") { isSearchFocused = true }.keyboardShortcut(MainWindowKey.search, modifiers: .command)
            Button("", action: model.refreshNow).keyboardShortcut(MainWindowKey.refresh, modifiers: .command)
            Button("", action: launchPrimaryClaude)
                .keyboardShortcut(KeyEquivalent(Character(ClaudeText.shortcutKey)), modifiers: .command)
            Button("") { terminals.isPanelVisible.toggle() }
                .keyboardShortcut(TerminalKey.togglePanel, modifiers: .command)
            Button("", action: focusNextSession)
                .keyboardShortcut(TerminalKey.nextSession, modifiers: .control)
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func selectSession(_ session: TerminalSessionInfo) {
        terminals.focus(session.id)
        terminals.isPanelVisible = true
        reveal(pullRequest: session.pullRequestID)
    }

    private func focusNextSession() {
        terminals.focusNext()
        guard let session = terminals.registry.focused else { return }
        terminals.isPanelVisible = true
        reveal(pullRequest: session.pullRequestID)
    }

    private func reveal(pullRequest id: String) {
        let target = ListTab.allCases.first { candidate in
            listing(candidate).source().contains { $0.id == id }
        }
        isApplyingRequest = true
        if let target, target != tab {
            tab = target
        }
        if !items(for: tab, now: .now).contains(where: { $0.id == id }) {
            scope = .all
            query = ""
        }
        selectedID = id
        DispatchQueue.main.async { isApplyingRequest = false }
    }

    private func launchPrimaryClaude() {
        guard let pr = selectedPullRequest else { return }
        let entry = listing(tab).menuEntries(for: pr).first { if case .claude(_, true) = $0 { true } else { false } }
        guard let entry else {
            NSSound.beep()
            return
        }
        model.perform(entry, on: pr)
    }
}
