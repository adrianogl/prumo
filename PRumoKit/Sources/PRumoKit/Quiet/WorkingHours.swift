import Foundation

public struct WorkingHours: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var weekdays: Set<Int>
    public var startMinute: Int
    public var endMinute: Int

    public var isValid: Bool { startMinute < endMinute }

    public init(
        enabled: Bool = false,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        startMinute: Int = 540,
        endMinute: Int = 1080
    ) {
        self.enabled = enabled
        self.weekdays = weekdays
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, weekdays, startMinute, endMinute
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WorkingHours()
        enabled = c.decodeLossy(Bool.self, forKey: .enabled, default: defaults.enabled)
        weekdays = c.decodeLossy(Set<Int>.self, forKey: .weekdays, default: defaults.weekdays)
        startMinute = c.decodeLossy(Int.self, forKey: .startMinute, default: defaults.startMinute)
        endMinute = c.decodeLossy(Int.self, forKey: .endMinute, default: defaults.endMinute)
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard isValid else { return true }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, weekdays.contains(weekday) else { return false }
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minute >= startMinute && minute < endMinute
    }
}
