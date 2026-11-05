import Foundation

enum ClockFormat {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = PopoverText.clockFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
