import Foundation

public enum WidgetSharedStore {
    public static let appGroupIdentifier = "group.dev.aglv.prumo"
    public static let fileName = "widget.json"

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
