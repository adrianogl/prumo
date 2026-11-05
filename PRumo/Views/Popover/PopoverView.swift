import SwiftUI
import PRumoKit

struct PopoverView: View {
    let model: AppModel
    @State private var tab: PopoverTab = .mine
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var mine: [PullRequest] { model.snapshot?.mine ?? [] }
    private var review: [PullRequest] { model.snapshot?.toReview ?? [] }
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
            tabButton(PopoverText.mineTab, count: mine.count, tab: .mine)
            tabButton(PopoverText.reviewTab, count: review.count, tab: .review)
        }
        .padding(2)
        .background(Color.prumoBadgeBackground, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func tabButton(_ title: String, count: Int, tab target: PopoverTab) -> some View {
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
            let items = tab == .mine ? mine : review
            if items.isEmpty {
                Text(tab == .mine ? PopoverText.emptyMine : PopoverText.emptyReview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { pr in
                                PRRowView(pr: pr, presentation: presentation(for: pr, now: context.date), tab: tab, model: model)
                                if pr.id != items.last?.id { Divider() }
                            }
                        }
                    }
                    .frame(maxHeight: PopoverMetrics.listMaxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func presentation(for pr: PullRequest, now: Date) -> RowPresentation {
        let jiraKey = model.integrations.link(for: pr)?.key
        return switch tab {
        case .mine: RowPresenter.mine(pr, viewer: model.snapshot?.viewer ?? "", now: now, jiraKey: jiraKey)
        case .review: RowPresenter.review(pr, now: now, jiraKey: jiraKey)
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
