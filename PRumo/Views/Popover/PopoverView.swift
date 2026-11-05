import SwiftUI
import PRumoKit

struct PopoverView: View {
    let model: AppModel
    @State private var tab: ListTab = .mine
    @State private var highlighted: Set<String> = []
    @State private var isOpen = false
    @State private var openGeneration = 0
    @State private var window: NSWindow?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var organization: OrganizationStore { model.organization }
    private var viewer: String { model.snapshot?.viewer ?? "" }
    private var isLoading: Bool { model.snapshot == nil && model.connection == .ok && !model.needsOnboarding }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            StatusBanner(connection: model.connection, nextRefresh: model.nextRefresh, onReconnect: showOnboarding)
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: PopoverMetrics.width)
        .background(Color.prumoPopoverBackground)
        .background(WindowReader { reached in
            window = reached
            if reached?.isKeyWindow == true { open() }
        })
        .onAppear(perform: open)
        .onDisappear(perform: close)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            if isPopoverWindow(note.object) { open() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            if isPopoverWindow(note.object) { close() }
        }
    }

    private func isPopoverWindow(_ object: Any?) -> Bool {
        guard let window, let other = object as? NSWindow else { return false }
        return other === window
    }

    private func open() {
        guard !isOpen else { return }
        isOpen = true
        highlighted = organization.unseen
        openGeneration += 1
    }

    private func close() {
        isOpen = false
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
            snapshot.mine.filter { MergeReadiness.isReady($0, viewer: snapshot.viewer) }
        }
    }

    private func rows(for tab: ListTab, now: Date) -> [PullRequest] {
        let settings = organization.settings
        let context = FilterContext(
            viewer: viewer, marks: settings.marks, unseen: highlighted.union(organization.unseen), now: now)
        let filtered = RowFiltering.apply(source(for: tab), filter: settings.filter, tab: tab, context: context)
        return RowOrdering.sections(
            filtered, tab: tab, ordering: settings.ordering(for: tab), marks: settings.marks, viewer: viewer
        ).flatMap(\.items)
    }

    private func mergedToday(now: Date) -> [MergedPullRequest] {
        MergedToday.items(model.snapshot?.mergedToday ?? [], now: now, calendar: .current)
    }

    private func showOnboarding() {
        openWindow(id: PopoverText.onboardingWindowID)
        NSApp.activate()
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
            tabButton(PopoverText.mineTab, count: rows(for: .mine, now: .now).count, tab: .mine)
            tabButton(PopoverText.reviewTab, count: rows(for: .review, now: .now).count, tab: .review)
            tabButton(PopoverText.mergeTab, count: rows(for: .merge, now: .now).count, tab: .merge)
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
                let items = rows(for: tab, now: context.date)
                let merged = tab == .merge ? mergedToday(now: context.date) : []
                if items.isEmpty && merged.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if items.isEmpty { emptyState }
                            ForEach(items) { pr in
                                row(pr, now: context.date)
                                if pr.id != items.last?.id { Divider() }
                            }
                            if !merged.isEmpty { mergedSection(merged) }
                        }
                    }
                    .id(openGeneration)
                    .frame(maxHeight: PopoverMetrics.listMaxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        switch tab {
        case .mine: PopoverText.emptyMine
        case .review: PopoverText.emptyReview
        case .merge: PopoverText.emptyMerge
        }
    }

    private func row(_ pr: PullRequest, now: Date) -> some View {
        let compact = organization.settings.rowStyle == .compact
        return PRRowView(
            pr: pr,
            presentation: presentation(for: pr, now: now),
            compactLine: compact ? RowPresenter.compactLine(pr, tab: tab, viewer: viewer, now: now) : nil,
            tab: tab,
            isHighlighted: highlighted.contains(pr.id),
            model: model)
            .onAppear { organization.markSeen([pr.id]) }
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
                MergedRowView(item: item)
            }
        }
    }

    private func presentation(for pr: PullRequest, now: Date) -> RowPresentation {
        let jiraKey = model.integrations.link(for: pr)?.key
        return switch tab {
        case .mine: RowPresenter.mine(pr, viewer: viewer, now: now, jiraKey: jiraKey)
        case .review: RowPresenter.review(pr, now: now, jiraKey: jiraKey)
        case .merge: RowPresenter.merge(pr, viewer: viewer, now: now, jiraKey: jiraKey)
        }
    }

    private var footer: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if let last = model.lastRefresh ?? model.snapshot?.fetchedAt {
                    Text(PopoverText.updatedAgo(seconds: max(0, Int(context.date.timeIntervalSince(last)))))
                } else if model.connection == .ok {
                    Text(PopoverText.updating)
                }
            }
            Spacer()
            Button(action: showSettings) {
                Label(PopoverText.settings, systemImage: PopoverSymbol.settings)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
