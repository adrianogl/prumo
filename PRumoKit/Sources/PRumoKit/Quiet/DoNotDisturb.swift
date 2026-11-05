import Foundation

public enum DoNotDisturb: Codable, Equatable, Sendable {
    case off
    case until(Date)
    case indefinite

    private enum CodingKeys: String, CodingKey {
        case kind, until
    }

    public init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = .off
            return
        }
        let kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? nil
        switch kind {
        case "indefinite":
            self = .indefinite
        case "until":
            if let date = (try? c.decodeIfPresent(Date.self, forKey: .until)) ?? nil {
                self = .until(date)
            } else {
                self = .off
            }
        default:
            self = .off
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .off:
            try c.encode("off", forKey: .kind)
        case .indefinite:
            try c.encode("indefinite", forKey: .kind)
        case .until(let date):
            try c.encode("until", forKey: .kind)
            try c.encode(date, forKey: .until)
        }
    }

    public static func oneHour(from now: Date) -> DoNotDisturb {
        .until(now.addingTimeInterval(3600))
    }

    public static func untilTomorrowMorning(from now: Date, calendar: Calendar) -> DoNotDisturb {
        let startOfToday = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let nineAM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
        else { return .oneHour(from: now) }
        return .until(nineAM)
    }

    public func isActive(at now: Date) -> Bool {
        switch self {
        case .off: false
        case .indefinite: true
        case .until(let end): now < end
        }
    }

    public func normalized(at now: Date) -> DoNotDisturb {
        if case .until(let end) = self, now >= end { return .off }
        return self
    }
}
