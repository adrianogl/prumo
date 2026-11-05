import Foundation
import PRumoKit
import WidgetKit

@MainActor
final class WidgetPublisher {
    private let fileURL: URL
    private var lastPublished: WidgetSnapshot?

    private let now: () -> Date

    init(fileURL: URL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
    }

    static func makeDefault() -> WidgetPublisher? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetSharedStore.appGroupIdentifier)
            .map { WidgetPublisher(fileURL: $0.appendingPathComponent(WidgetSharedStore.fileName)) }
    }

    func publish(_ snapshot: WidgetSnapshot) {
        let decision = WidgetPublishDecision.make(
            new: snapshot, lastPublished: lastPublished, now: now(), renewAfter: AppConstants.widgetRenewAfter
        )
        guard decision.write else { return }
        guard let data = try? WidgetSharedStore.makeEncoder().encode(snapshot) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
        lastPublished = snapshot
        if decision.reload {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
