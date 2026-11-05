import Foundation

public enum AccountSchedule {
    public static func shouldRefresh(_ state: ConnectionState?, now: Date) -> Bool {
        switch state {
        case .unauthorized: false
        case .rateLimited(let resetAt?): resetAt <= now
        default: true
        }
    }
}
