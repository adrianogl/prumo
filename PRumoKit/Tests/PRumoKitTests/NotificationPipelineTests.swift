import Foundation
import Testing
@testable import PRumoKit

@Suite struct NotificationPipelineTests {
    private let hour: TimeInterval = 3600

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func event(_ kind: NotificationKind, pr: String = "PR_1") -> NotificationEvent {
        NotificationEvent(
            kind: kind, pullRequestID: pr, title: "t", body: "b",
            url: URL(string: "https://github.com/acme/loja/pull/1")!
        )
    }

    private func staleSnapshot(hoursAgo: Double = 30, id: String = "PR_9", target: ReviewRequestTarget = .you) -> Snapshot {
        .fixture(toReview: [
            .fixture(
                id: id, number: 9, reviewRequestedAt: Date.fixed.addingTimeInterval(-hoursAgo * hour),
                reviewTarget: target
            ),
        ])
    }

    private var initialized: ReminderState { ReminderState(initialized: true) }

    private func run(
        _ events: [NotificationEvent] = [], snapshot: Snapshot = .fixture(),
        preferences: NotificationPreferences = NotificationPreferences(), muted: Set<String> = [],
        includeTeam: Bool = true, reminders: ReminderState = ReminderState(initialized: true),
        now: Date = .fixed
    ) -> PipelineResult {
        NotificationPipeline.run(
            events: events, snapshot: snapshot, preferences: preferences, muted: muted,
            ignoreDrafts: true, includeTeam: includeTeam, reminders: reminders, now: now, calendar: calendar
        )
    }

    @Test func passesEnabledEventsOutsideQuiet() {
        let events = [event(.approved), event(.conflict)]
        #expect(run(events).deliver == events)
    }

    @Test func quietDropsTransitionEvents() {
        var preferences = NotificationPreferences()
        preferences.dnd = .indefinite
        #expect(run([event(.approved), event(.ciFailed)], preferences: preferences).deliver.isEmpty)
    }

    @Test func outsideWorkingHoursDropsTransitionEvents() {
        var preferences = NotificationPreferences()
        preferences.workingHours = WorkingHours(enabled: true, weekdays: [1, 2, 3, 4, 5, 6, 7], startMinute: 0, endMinute: 60)
        #expect(run([event(.approved)], preferences: preferences).deliver.isEmpty)
    }

    @Test func mutedDropped() {
        let kept = event(.approved, pr: "PR_2")
        #expect(run([event(.approved, pr: "PR_1"), kept], muted: ["PR_1"]).deliver == [kept])
    }

    @Test func mutedStaleNeverDeliveredNorMarked() {
        let result = run(snapshot: staleSnapshot(), muted: ["PR_9"])
        #expect(result.deliver.isEmpty)
        #expect(result.reminders.reminded.isEmpty)
    }

    @Test func disabledKindDropped() {
        var preferences = NotificationPreferences()
        preferences.disabled = [.newComment]
        let kept = event(.approved)
        #expect(run([event(.newComment), kept], preferences: preferences).deliver == [kept])
    }

    @Test func ciToggleCoversFailedAndSucceeded() {
        #expect(NotificationToggle(kind: .ciFailed) == .ci)
        #expect(NotificationToggle(kind: .ciSucceeded) == .ci)
        var preferences = NotificationPreferences()
        preferences.disabled = [.ci]
        #expect(!preferences.isEnabled(.ciFailed))
        #expect(!preferences.isEnabled(.ciSucceeded))
        #expect(run([event(.ciFailed), event(.ciSucceeded)], preferences: preferences).deliver.isEmpty)
    }

    @Test func toggleMapsOtherKindsByName() {
        #expect(NotificationToggle(kind: .approved) == .approved)
        #expect(NotificationToggle(kind: .changesRequested) == .changesRequested)
        #expect(NotificationToggle(kind: .newComment) == .newComment)
        #expect(NotificationToggle(kind: .reviewRequested) == .reviewRequested)
        #expect(NotificationToggle(kind: .staleReview) == .staleReview)
        #expect(NotificationToggle(kind: .readyToMerge) == .readyToMerge)
        #expect(NotificationToggle(kind: .conflict) == .conflict)
    }

    @Test func firstRunMarksExistingStaleWithoutDelivering() {
        let snapshot = staleSnapshot()
        let first = run(snapshot: snapshot, reminders: ReminderState())
        #expect(first.deliver.isEmpty)
        #expect(first.reminders.initialized)
        #expect(first.reminders.reminded == [StaleReviewTracker.key(for: snapshot.toReview[0])])
        #expect(run(snapshot: snapshot, reminders: first.reminders).deliver.isEmpty)
    }

    @Test func firstRunMarksEvenWhileQuiet() {
        var preferences = NotificationPreferences()
        preferences.dnd = .indefinite
        let result = run(snapshot: staleSnapshot(), preferences: preferences, reminders: ReminderState())
        #expect(result.deliver.isEmpty)
        #expect(result.reminders.initialized)
        #expect(result.reminders.reminded.count == 1)
    }

    @Test func firstRunStillDeliversTransitionEvents() {
        let approved = event(.approved)
        #expect(run([approved], snapshot: staleSnapshot(), reminders: ReminderState()).deliver == [approved])
    }

    @Test func staleDuringQuietIsPostponedNotDropped() {
        let snapshot = staleSnapshot()
        var quiet = NotificationPreferences()
        quiet.dnd = .until(Date.fixed.addingTimeInterval(hour))

        let during = run([event(.approved)], snapshot: snapshot, preferences: quiet, reminders: initialized)
        #expect(during.deliver.isEmpty)
        #expect(during.reminders == initialized)

        let after = Date.fixed.addingTimeInterval(2 * hour)
        let resumed = run([event(.conflict)], snapshot: snapshot, preferences: quiet, reminders: during.reminders, now: after)
        #expect(resumed.deliver.map(\.kind) == [.conflict, .staleReview])
        #expect(resumed.deliver.last?.pullRequestID == "PR_9")
        #expect(resumed.reminders.reminded == [StaleReviewTracker.key(for: snapshot.toReview[0])])

        let third = run(snapshot: snapshot, preferences: quiet, reminders: resumed.reminders, now: after.addingTimeInterval(hour))
        #expect(third.deliver.isEmpty)
        #expect(third.reminders == resumed.reminders)
    }

    @Test func disabledStaleToggleMarksWithoutDelivering() {
        let snapshot = staleSnapshot()
        var off = NotificationPreferences()
        off.disabled = [.staleReview]

        let disabled = run(snapshot: snapshot, preferences: off)
        #expect(disabled.deliver.isEmpty)
        #expect(disabled.reminders.reminded == [StaleReviewTracker.key(for: snapshot.toReview[0])])

        let reenabled = run(snapshot: snapshot, reminders: disabled.reminders)
        #expect(reenabled.deliver.isEmpty)
    }

    @Test func staleLimitFollowsPreferenceHours() {
        var preferences = NotificationPreferences()
        preferences.staleReviewHours = 48
        #expect(run(snapshot: staleSnapshot(hoursAgo: 30), preferences: preferences).deliver.isEmpty)
        #expect(run(snapshot: staleSnapshot(hoursAgo: 49), preferences: preferences).deliver.count == 1)
    }

    @Test func teamStaleFollowsIncludeTeam() {
        let snapshot = staleSnapshot(target: .team(name: "backend"))
        #expect(run(snapshot: snapshot, includeTeam: true).deliver.count == 1)
        let excluded = run(snapshot: snapshot, includeTeam: false)
        #expect(excluded.deliver.isEmpty)
        #expect(excluded.reminders.reminded.isEmpty)
    }

    @Test func emptyJSONDecodesDefaults() throws {
        let preferences = try JSONDecoder().decode(NotificationPreferences.self, from: Data("{}".utf8))
        #expect(preferences.staleReviewHours == 24)
        #expect(preferences.groupByPullRequest == true)
        #expect(preferences.dnd == .off)
        #expect(preferences.workingHours.enabled == false)
        #expect(preferences.disabled.isEmpty)
        #expect(preferences == NotificationPreferences())
    }

    @Test func invalidFieldsFallBackToDefaults() throws {
        let json = #"{"disabled":"x","groupByPullRequest":3,"staleReviewHours":"a","dnd":7,"workingHours":[]}"#
        let preferences = try JSONDecoder().decode(NotificationPreferences.self, from: Data(json.utf8))
        #expect(preferences == NotificationPreferences())
    }

    @Test func nonPositiveStaleReviewHoursFallBackToDefault() throws {
        for hours in [0, -5] {
            let json = #"{"staleReviewHours": \#(hours)}"#
            let preferences = try JSONDecoder().decode(NotificationPreferences.self, from: Data(json.utf8))
            #expect(preferences.staleReviewHours == 24)
        }
    }

    @Test func newKindsDefaultOn() throws {
        let json = #"{"disabled":["ci","approved","kindFromTheFuture"]}"#
        let preferences = try JSONDecoder().decode(NotificationPreferences.self, from: Data(json.utf8))
        #expect(preferences.disabled == [.ci, .approved])
        #expect(preferences.isEnabled(.readyToMerge))
        #expect(preferences.isEnabled(.conflict))
        #expect(preferences.isEnabled(.staleReview))
        #expect(!preferences.isEnabled(.approved))
    }

    @Test func roundTripKeepsActiveUntil() throws {
        var preferences = NotificationPreferences()
        preferences.disabled = [.newComment, .conflict]
        preferences.groupByPullRequest = false
        preferences.staleReviewHours = 8
        preferences.dnd = .until(Date.fixed.addingTimeInterval(1800.5))
        preferences.workingHours = WorkingHours(enabled: true, weekdays: [2, 3], startMinute: 480, endMinute: 1020)
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)
        #expect(decoded == preferences)
        #expect(decoded.dnd.isActive(at: .fixed))
    }
}
