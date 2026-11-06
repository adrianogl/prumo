import Foundation
import PRumoKit

@MainActor
struct PullRequestListing {
    let model: AppModel
    let tab: ListTab

    private var organization: OrganizationStore { model.organization }
    private var viewer: String { model.snapshot?.viewer ?? "" }
    private var hasMultipleAccounts: Bool { model.accounts.list.accounts.count > 1 }

    var staleLimit: TimeInterval { TimeInterval(model.preferences.preferences.staleReviewHours * 3600) }

    func viewer(for pr: PullRequest) -> String {
        model.snapshot?.viewer(for: pr) ?? viewer
    }

    func source() -> [PullRequest] {
        guard let snapshot = model.snapshot else { return [] }
        return TabSource.pullRequests(snapshot, tab: tab, settings: organization.settings)
    }

    func sections(filter: RowFilter, query: String, highlighted: Set<String>, now: Date) -> [RowSection] {
        let settings = organization.settings
        let context = FilterContext(
            viewer: viewer, viewers: model.snapshot?.accountViewers ?? [:], marks: settings.marks,
            unseen: highlighted.union(organization.unseen), staleLimit: staleLimit, now: now)
        let filtered = RowFiltering.apply(source(), filter: filter, tab: tab, context: context)
        let searched = query.isEmpty ? filtered : filtered.filter { SearchMatcher.matches($0, query: query) }
        return RowOrdering.sections(
            searched, tab: tab, ordering: settings.ordering(for: tab), marks: settings.marks,
            viewer: { model.snapshot?.viewer(for: $0) ?? viewer })
    }

    func staleSince(accountID: String) -> (isStale: Bool, since: Date?) {
        guard hasMultipleAccounts, let status = model.accounts.statuses[accountID], status.isProblem else {
            return (false, nil)
        }
        return (true, status.lastSuccess)
    }

    func presentation(for pr: PullRequest, now: Date) -> RowPresentation {
        let jiraKey = model.integrations.link(for: pr)?.key
        let account = model.accountLabel(for: pr)
        let stale = staleSince(accountID: pr.accountID).since
        let stuck = model.stuckCIDuration(for: pr, now: now)
        return switch tab {
        case .mine: RowPresenter.mine(
            pr, viewer: viewer(for: pr), now: now, jiraKey: jiraKey, commentFilter: organization.settings.commentAuthorFilter,
            account: account, staleSince: stale, ciStuckFor: stuck)
        case .review: RowPresenter.review(
            pr, now: now, jiraKey: jiraKey, staleLimit: staleLimit, account: account, staleSince: stale, ciStuckFor: stuck)
        case .merge: RowPresenter.merge(
            pr, viewer: viewer(for: pr), now: now, jiraKey: jiraKey, account: account, staleSince: stale, ciStuckFor: stuck)
        }
    }

    func menuEntries(for pr: PullRequest, now: Date = .now) -> [RowMenuEntry] {
        PRRowView.menuEntries(pr: pr, tab: tab, presentation: presentation(for: pr, now: now), model: model)
    }
}
