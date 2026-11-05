import Foundation

public enum RelativeAge {
    public static func string(from: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(from)))
        switch seconds {
        case ..<60: return PresentationText.now
        case ..<3600: return "\(seconds / 60)min"
        case ..<86400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86400)d"
        }
    }
}
