import Foundation

public enum QuietPolicy {
    public static func isQuiet(now: Date, dnd: DoNotDisturb, hours: WorkingHours, calendar: Calendar) -> Bool {
        dnd.isActive(at: now) || (hours.enabled && !hours.contains(now, calendar: calendar))
    }
}
