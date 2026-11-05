import PRumoKit
import WidgetKit

struct PRumoEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct PRumoProvider: TimelineProvider {
    func placeholder(in context: Context) -> PRumoEntry {
        PRumoEntry(date: .now, snapshot: Self.placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (PRumoEntry) -> Void) {
        let snapshot = context.isPreview ? Self.placeholderSnapshot : Self.load()
        completion(PRumoEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PRumoEntry>) -> Void) {
        let now = Date.now
        let entry = PRumoEntry(date: now, snapshot: Self.load())
        let next = now.addingTimeInterval(WidgetMetrics.reloadInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    static func load() -> WidgetSnapshot {
        guard
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetStorage.appGroupIdentifier),
            let data = try? Data(contentsOf: container.appendingPathComponent(WidgetStorage.fileName))
        else { return .disconnected }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetSnapshot.self, from: data)) ?? .disconnected
    }

    static var placeholderSnapshot: WidgetSnapshot {
        let base = URL(string: "https://github.com/")!
        let items = zip(WidgetPlaceholder.items, [WidgetReason.ciFailing, .staleReview, .readyToMerge]).map { entry, reason in
            WidgetItem(
                id: "\(entry.number)", number: entry.number, title: entry.title, url: base,
                reason: reason, waitingHours: entry.hours
            )
        }
        return WidgetSnapshot(connected: true, toReview: 3, ciFailing: 1, readyToMerge: 2, items: items, updatedAt: .now)
    }
}
