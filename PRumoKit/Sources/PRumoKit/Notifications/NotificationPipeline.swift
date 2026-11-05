import Foundation

public enum NotificationPipeline {
    public static func run(
        events: [NotificationEvent], snapshot: Snapshot, preferences: NotificationPreferences,
        muted: Set<String>, ignoreDrafts: Bool, includeTeam: Bool, reminders: ReminderState,
        now: Date, calendar: Calendar
    ) -> PipelineResult {
        let quiet = QuietPolicy.isQuiet(now: now, dnd: preferences.dnd, hours: preferences.workingHours, calendar: calendar)
        var deliver = quiet ? [] : events.filter { preferences.isEnabled($0.kind) && !muted.contains($0.pullRequestID) }
        var state = reminders

        func due() -> [StaleReminder] {
            StaleReviewTracker.due(
                snapshot: snapshot,
                limit: TimeInterval(preferences.staleReviewHours) * ReminderConstants.secondsPerHour,
                reminded: Set(state.reminded), muted: muted,
                ignoreDrafts: ignoreDrafts, includeTeam: includeTeam, now: now
            )
        }

        let accounts = snapshot.accountViewers.isEmpty ? [""] : Set(snapshot.accountViewers.keys).sorted()
        let known = Set(state.baselined)
        let pending = due()
        let fresh = pending.filter { !known.contains($0.event.accountID) }
        state.insert(fresh.map(\.key))
        if !quiet {
            let stale = pending.filter { known.contains($0.event.accountID) }
            state.insert(stale.map(\.key))
            if preferences.isEnabled(.staleReview) {
                deliver += stale.map(\.event)
            }
        }
        state.baselined = accounts
        state.initialized = true
        return PipelineResult(deliver: deliver, reminders: state)
    }
}
