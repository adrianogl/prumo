import SwiftUI
import WidgetKit

struct PRumoEntry: TimelineEntry {
    let date: Date
}

struct PRumoProvider: TimelineProvider {
    func placeholder(in context: Context) -> PRumoEntry {
        PRumoEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PRumoEntry) -> Void) {
        completion(PRumoEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PRumoEntry>) -> Void) {
        completion(Timeline(entries: [PRumoEntry(date: .now)], policy: .never))
    }
}

struct PRumoWidgetView: View {
    let entry: PRumoEntry

    var body: some View {
        Text(PRumoWidgetText.title)
            .font(.headline)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct PRumoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PRumoWidgetText.kind, provider: PRumoProvider()) { entry in
            PRumoWidgetView(entry: entry)
        }
        .configurationDisplayName(PRumoWidgetText.displayName)
        .description(PRumoWidgetText.description)
        .supportedFamilies([.systemSmall])
    }
}
