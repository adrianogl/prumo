import Foundation

func fixture(_ name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! Data(contentsOf: url)
}

extension Date {
    static let fixed = ISO8601DateFormatter().date(from: "2026-11-05T13:52:00Z")!
}
