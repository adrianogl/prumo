import SwiftUI
import PRumoKit

struct PopoverView: View {
    let model: AppModel
    @State private var tab: ListTab = .mine
    @State private var highlighted: Set<String> = []
    @State private var isOpen = false
    @State private var openGeneration = 0
    @State private var window: NSWindow?
    @State private var isPresentingPicker = false
    @State private var query = ""
    @State private var selectedID: String?
    @State private var rowFrames: [String: CGRect] = [:]
    @FocusState private var focus: PopoverFocus?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var organization: OrganizationStore { model.organization }
    private var staleLimit: TimeInterval { TimeInterval(model.preferences.preferences.staleReviewHours * 3600) }
    private var viewer: String { model.snapshot?.viewer ?? "" }

    private func viewer(for pr: PullRequest) -> String {
        model.snapshot?.viewer(for: pr) ?? viewer
    }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isLoading: Bool { model.snapshot == nil && model.connection == .ok && !model.needsOnboarding }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                header
                    .onChange(of: context.date, initial: true) { _, date in
                        model.preferences.refreshQuiet(now: date)
                    }
            }
            tabs
            if !model.needsOnboarding {
                FilterBar(organization: organization, snapshot: model.snapshot, accounts: model.accounts.list.accounts, tab: tab, staleHours: model.preferences.preferences.staleReviewHours, isPresentingPicker: $isPresentingPicker)
            }
            if !model.needsOnboarding {
                SearchField(text: $query, focus: $focus, onListKey: { handleListKey($0) ?? .ignored })
            }
            banners
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: PopoverMetrics.width)
        .background(Color.prumoPopoverBackground)
        .focusable()
        .focusEffectDisabled()
        .focused($focus, equals: .list)
        .onKeyPress(phases: .down, action: handleKeyPress)
        .onExitCommand(perform: exitCommand)
        .onPreferenceChange(RowFramePreference.self) { frames in
            MainActor.assumeIsolated { rowFrames = frames }
        }
        .onChange(of: visibleIDs) { _, ids in
            selectedID = KeyboardSelection.validated(selectedID, in: ids)
        }
        .onChange(of: tab) {
            selectedID = nil
        }
        .background(WindowReader { reached in
            window = reached
            if reached?.isKeyWindow == true { open() }
        })
        .onAppear(perform: open)
        .onDisappear(perform: close)
        .onChange(of: isPresentingPicker) { _, isPresenting in
            if !isPresenting && (!NSApp.isActive || window?.isVisible != true) { close() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if isPopoverWindow(note.object) { open() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            if isPopoverWindow(note.object) && !isPresentingPicker { close() }
        }
    }

    private func isPopoverWindow(_ object: Any?) -> Bool {
        guard let window, let other = object as? NSWindow else { return false }
        return other === window
    }

    private func open() {
        guard !isOpen else { return }
        isOpen = true
        if focus == nil { focus = .list }
        highlighted = organization.unseen
        openGeneration += 1
        model.refreshGhActiveLogin()
    }

    private func close() {
        isOpen = false
        selectedID = nil
        clearSearch()
    }

    private var exitCommand: (() -> Void)? {
        if query.isEmpty { return nil }
        return {
            if isRowMenuShortcut(NSApp.currentEvent) {
                _ = showRowMenu()
            } else {
                clearSearch()
            }
        }
    }

    private func isRowMenuShortcut(_ event: NSEvent?) -> Bool {
        guard let event, event.type == .keyDown else { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        return modifiers == .command && event.charactersIgnoringModifiers == String(PopoverKey.rowMenu)
    }

    private func clearSearch() {
        query = ""
        focus = .list
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .escape {
            guard !query.isEmpty else { return .ignored }
            clearSearch()
            return .handled
        }
        if let result = handleListKey(press) { return result }
        guard focus != .search, !model.needsOnboarding,
              press.modifiers.isDisjoint(with: [.command, .control]),
              let first = press.characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(first),
              !CharacterSet.whitespacesAndNewlines.contains(first),
              !(0xF700...0xF8FF).contains(first.value)
        else { return .ignored }
        query += press.characters
        focus = .search
        return .handled
    }

    private func handleListKey(_ press: KeyPress) -> KeyPress.Result? {
        let modifiers = press.modifiers.intersection([.command, .shift, .option, .control])
        if modifiers.isEmpty {
            switch press.key {
            case .downArrow: return moveSelection(.down)
            case .upArrow: return moveSelection(.up)
            case .return: return perform { _ in .openInBrowser }
            default: return nil
            }
        }
        let key = Character(press.key.character.lowercased())
        if modifiers == [.command, .shift] {
            guard key == PopoverKey.copy, focus != .search else { return nil }
            return perform { entries in entries.first { if case .copyCheckout = $0 { true } else { false } } }
        }
        guard modifiers == .command else { return nil }
        switch key {
        case PopoverKey.mineTab: return switchTab(.mine)
        case PopoverKey.reviewTab: return switchTab(.review)
        case PopoverKey.mergeTab: return switchTab(.merge)
        case PopoverKey.rowMenu: return showRowMenu()
        case PopoverKey.claude: return launchClaude()
        case PopoverKey.openJira:
            guard focus != .search else { return nil }
            return perform { entries in entries.first { if case .openJira = $0 { true } else { false } } }
        case PopoverKey.copy:
            guard focus != .search else { return nil }
            return perform { _ in .copyLink }
        default: return nil
        }
    }

    private var visiblePullRequests: [PullRequest] {
        guard model.snapshot != nil, !model.needsOnboarding else { return [] }
        return sections(for: tab, now: .now).flatMap(\.items)
    }

    private var visibleIDs: [String] { visiblePullRequests.map(\.id) }

    private var selectedPullRequest: PullRequest? {
        guard let selectedID else { return nil }
        return visiblePullRequests.first { $0.id == selectedID }
    }

    private func menuEntries(for pr: PullRequest) -> [RowMenuEntry] {
        PRRowView.menuEntries(pr: pr, tab: tab, presentation: presentation(for: pr, now: .now), model: model)
    }

    private func moveSelection(_ direction: MoveDirection) -> KeyPress.Result {
        let ids = visibleIDs
        guard !ids.isEmpty else { return .ignored }
        selectedID = KeyboardSelection.move(from: selectedID, in: ids, direction: direction)
        return .handled
    }

    private func switchTab(_ target: ListTab) -> KeyPress.Result {
        tab = target
        selectedID = nil
        return .handled
    }

    private func perform(_ pick: ([RowMenuEntry]) -> RowMenuEntry?) -> KeyPress.Result {
        guard let pr = selectedPullRequest, let entry = pick(menuEntries(for: pr)) else { return .ignored }
        model.perform(entry, on: pr)
        return .handled
    }

    private func launchClaude() -> KeyPress.Result {
        guard let pr = selectedPullRequest else { return .ignored }
        guard let entry = menuEntries(for: pr).first(where: { if case .claude = $0 { true } else { false } }) else {
            NSSound.beep()
            return .handled
        }
        model.perform(entry, on: pr)
        return .handled
    }

    private func showRowMenu() -> KeyPress.Result {
        guard let pr = selectedPullRequest, let frame = rowFrames[pr.id],
              let view = window?.contentView
        else { return .ignored }
        let y = view.isFlipped ? frame.maxY : view.bounds.height - frame.maxY
        let entries = menuEntries(for: pr)
        RowMenuNSMenu.show(entries: entries, isRerunning: model.isRerunning(pr), at: NSPoint(x: frame.minX, y: y), in: view) { entry in
            model.perform(entry, on: pr)
        }
        return .handled
    }

    private func source(for tab: ListTab) -> [PullRequest] {
        guard let snapshot = model.snapshot else { return [] }
        let settings = organization.settings
        return switch tab {
        case .mine:
            snapshot.mine
        case .review:
            ReviewInclusion.visible(
                snapshot.toReview, ignoreDrafts: settings.ignoreDraftsInReview,
                includeTeam: settings.includeTeamRequests)
        case .merge:
            snapshot.mine.filter { MergeReadiness.isReady($0, viewer: snapshot.viewer(for: $0)) }
        }
    }

    private func sections(for tab: ListTab, now: Date) -> [RowSection] {
        let settings = organization.settings
        let context = FilterContext(
            viewer: viewer, viewers: model.snapshot?.accountViewers ?? [:], marks: settings.marks, unseen: highlighted.union(organization.unseen),
            staleLimit: staleLimit, now: now)
        let filtered = RowFiltering.apply(source(for: tab), filter: settings.filter, tab: tab, context: context)
        let searched = trimmedQuery.isEmpty ? filtered : filtered.filter { SearchMatcher.matches($0, query: trimmedQuery) }
        return RowOrdering.sections(
            searched, tab: tab, ordering: settings.ordering(for: tab), marks: settings.marks,
            viewer: { model.snapshot?.viewer(for: $0) ?? viewer })
    }

    private func rowCount(for tab: ListTab) -> Int {
        sections(for: tab, now: .now).reduce(0) { $0 + $1.items.count }
    }

    private func mergedToday(now: Date) -> [MergedPullRequest] {
        let repositories = organization.settings.filter.repositories
        return MergedToday.items(model.snapshot?.mergedToday ?? [], now: now, calendar: .current)
            .filter { repositories.isEmpty || repositories.contains($0.repositoryKey) }
            .filter { trimmedQuery.isEmpty || SearchMatcher.matches($0, query: trimmedQuery) }
    }

    private var hasMultipleAccounts: Bool { model.accounts.list.accounts.count > 1 }

    @ViewBuilder
    private var banners: some View {
        if hasMultipleAccounts {
            ForEach(model.accounts.list.accounts) { account in
                if let status = model.accounts.statuses[account.id], status.isProblem {
                    AccountProblemBanner(account: account, status: status, onSettings: showSettings)
                }
            }
        } else {
            StatusBanner(
                connection: model.connection, nextRefresh: model.nextRefresh,
                providerName: AccountsSettingsText.providerName(model.accounts.list.accounts.first?.provider ?? .github),
                onReconnect: reconnectOnlyAccount)
        }
    }

    private func staleSince(accountID: String) -> (isStale: Bool, since: Date?) {
        guard hasMultipleAccounts, let status = model.accounts.statuses[accountID], status.isProblem else {
            return (false, nil)
        }
        return (true, status.lastSuccess)
    }

    private func showOnboarding() {
        openWindow(id: PopoverText.onboardingWindowID)
        NSApp.activate()
    }

    private func reconnectOnlyAccount() {
        guard let account = model.accounts.list.accounts.first else { return showOnboarding() }
        switch OnboardingPolicy.recovery(for: account) {
        case .onboarding: showOnboarding()
        case .reconnect: model.reconnect(id: account.id)
        case .settings: showSettings()
        }
    }

    private func showSettings() {
        openSettings()
        NSApp.activate()
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(PopoverSymbol.appLogo)
                .resizable()
                .interpolation(.high)
                .frame(width: PopoverMetrics.headerIconSize, height: PopoverMetrics.headerIconSize)
            Wordmark(size: 16)
            Spacer()
            DoNotDisturbButton(store: model.preferences)
            Button(action: model.refreshNow) {
                Image(systemName: PopoverSymbol.refresh)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(PopoverText.refresh)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            tabButton(PopoverText.mineTab, count: rowCount(for: .mine), tab: .mine)
            tabButton(PopoverText.reviewTab, count: rowCount(for: .review), tab: .review)
            tabButton(PopoverText.mergeTab, count: rowCount(for: .merge), tab: .merge)
        }
        .padding(2)
        .background(Color.prumoBadgeBackground, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func tabButton(_ title: String, count: Int, tab target: ListTab) -> some View {
        let selected = tab == target
        return Button {
            tab = target
        } label: {
            HStack(spacing: 5) {
                Text(title)
                if model.snapshot != nil {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.prumoCaramel, in: Capsule())
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(selected ? Color(nsColor: .controlBackgroundColor) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var list: some View {
        if model.needsOnboarding {
            VStack(spacing: 10) {
                Text(PopoverText.connectPrompt)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button(PopoverText.connectAction, action: showOnboarding)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else if model.snapshot == nil && model.connection != .ok {
            EmptyView()
        } else if isLoading {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in PRRowSkeleton() }
            }
            .frame(maxWidth: .infinity)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let sections = sections(for: tab, now: context.date).filter { !$0.items.isEmpty }
                let merged = tab == .merge ? mergedToday(now: context.date) : []
                if sections.isEmpty && merged.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if sections.isEmpty { emptyState }
                                ForEach(sections, id: \.repository) { section in
                                    sectionView(section, isFirst: section.repository == sections.first?.repository, now: context.date)
                                }
                                if !merged.isEmpty { mergedSection(merged) }
                            }
                        }
                        .id(openGeneration)
                        .frame(maxHeight: PopoverMetrics.listMaxHeight)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: selectedID) { _, id in
                            guard let id else { return }
                            proxy.scrollTo(id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: RowSection, isFirst: Bool, now: Date) -> some View {
        if let repository = section.repository {
            if !isFirst { Divider() }
            SectionHeader(repository: repository, count: section.items.count)
        }
        ForEach(section.items) { pr in
            row(pr, now: now)
                .id(pr.id)
            if pr.id != section.items.last?.id { Divider() }
        }
    }

    private var emptyState: some View {
        Text(emptyText)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }

    private var emptyText: String {
        if !trimmedQuery.isEmpty { return PopoverText.nothingFound(query: trimmedQuery) }
        return switch tab {
        case .mine: PopoverText.emptyMine
        case .review: PopoverText.emptyReview
        case .merge: PopoverText.emptyMerge
        }
    }

    private func row(_ pr: PullRequest, now: Date) -> some View {
        let compact = organization.settings.rowStyle == .compact
        let isSelected = selectedID == pr.id
        return PRRowView(
            pr: pr,
            presentation: presentation(for: pr, now: now),
            compactLine: compact
                ? RowPresenter.compactLine(pr, tab: tab, viewer: viewer(for: pr), now: now, account: model.accountLabel(for: pr))
                : nil,
            tab: tab,
            isHighlighted: highlighted.contains(pr.id),
            isSelected: isSelected,
            hasOtherSelection: selectedID != nil && !isSelected,
            isStale: staleSince(accountID: pr.accountID).isStale,
            model: model)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: RowFramePreference.self,
                        value: isSelected ? [pr.id: geometry.frame(in: .global)] : [:])
                }
            }
            .onAppear {
                guard isOpen else { return }
                organization.markSeen([pr.id])
            }
    }

    private func mergedSection(_ merged: [MergedPullRequest]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Text(PopoverText.mergedToday(count: merged.count))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 4)
            ForEach(merged) { item in
                MergedRowView(
                    item: item,
                    account: AccountLabel.forRow(accountID: item.accountID, accounts: model.accounts.list.accounts),
                    isStale: staleSince(accountID: item.accountID).isStale)
            }
        }
    }

    private func presentation(for pr: PullRequest, now: Date) -> RowPresentation {
        let jiraKey = model.integrations.link(for: pr)?.key
        let account = model.accountLabel(for: pr)
        let stale = staleSince(accountID: pr.accountID).since
        return switch tab {
        case .mine: RowPresenter.mine(
            pr, viewer: viewer(for: pr), now: now, jiraKey: jiraKey, commentFilter: organization.settings.commentAuthorFilter,
            account: account, staleSince: stale)
        case .review: RowPresenter.review(
            pr, now: now, jiraKey: jiraKey, staleLimit: staleLimit, account: account, staleSince: stale)
        case .merge: RowPresenter.merge(
            pr, viewer: viewer(for: pr), now: now, jiraKey: jiraKey, account: account, staleSince: stale)
        }
    }

    private func footerStatus(now: Date) -> String? {
        if let last = model.lastRefresh ?? model.snapshot?.fetchedAt {
            return PopoverText.updatedAgo(seconds: max(0, Int(now.timeIntervalSince(last))))
        }
        return model.connection == .ok ? PopoverText.updating : nil
    }

    private var footer: some View {
        HStack {
            HStack(spacing: PopoverMetrics.footerSpacing) {
                if selectedID != nil {
                    Text(PopoverText.keyboardHint)
                        .font(.system(size: PopoverMetrics.footerFontSize, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if model.hotKeyRegistered {
                        Text(PopoverText.footerSeparator)
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let status = footerStatus(now: context.date) {
                            HStack(spacing: PopoverMetrics.footerSpacing) {
                                Text(status)
                                if model.hotKeyRegistered {
                                    Text(PopoverText.footerSeparator)
                                }
                            }
                        }
                    }
                }
                if model.hotKeyRegistered {
                    Text(model.hotKey.display)
                        .font(.system(size: PopoverMetrics.footerFontSize, design: .monospaced))
                        .fixedSize()
                }
            }
            Spacer()
            Button(action: showSettings) {
                Label(PopoverText.settings, systemImage: PopoverSymbol.settings)
            }
            .buttonStyle(.plain)
            .fixedSize()
        }
        .font(.system(size: PopoverMetrics.footerFontSize))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
