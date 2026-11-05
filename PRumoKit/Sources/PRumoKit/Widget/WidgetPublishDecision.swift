import Foundation

public struct WidgetPublishDecision: Equatable, Sendable {
    public let write: Bool
    public let reload: Bool

    public static func make(
        new: WidgetSnapshot, lastPublished: WidgetSnapshot?, now: Date, renewAfter: TimeInterval
    ) -> WidgetPublishDecision {
        guard let last = lastPublished else { return WidgetPublishDecision(write: true, reload: true) }
        if content(of: new) != content(of: last) {
            return WidgetPublishDecision(write: true, reload: true)
        }
        if now.timeIntervalSince(last.updatedAt) > renewAfter {
            return WidgetPublishDecision(write: true, reload: false)
        }
        return WidgetPublishDecision(write: false, reload: false)
    }

    private static func content(of snapshot: WidgetSnapshot) -> WidgetSnapshot {
        var copy = snapshot
        copy.updatedAt = Date(timeIntervalSince1970: 0)
        return copy
    }
}
