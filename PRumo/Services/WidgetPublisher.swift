import Foundation
import PRumoKit
import WidgetKit

@MainActor
final class WidgetPublisher {
    private let fileURL: URL
    private var lastPublished: WidgetSnapshot?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func makeDefault() -> WidgetPublisher? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier)
            .map { WidgetPublisher(fileURL: $0.appendingPathComponent(AppConstants.widgetFileName)) }
    }

    func publish(_ snapshot: WidgetSnapshot) {
        let content = Self.comparable(snapshot)
        guard content != lastPublished else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
        lastPublished = content
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func comparable(_ snapshot: WidgetSnapshot) -> WidgetSnapshot {
        var copy = snapshot
        copy.updatedAt = Date(timeIntervalSince1970: 0)
        return copy
    }
}
