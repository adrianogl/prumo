import SwiftUI
import WidgetKit

struct PRumoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PRumoEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium: MediumWidgetView(entry: entry)
            default: SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { Color.prumoPopoverBackground }
    }
}

struct PRumoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetText.kind, provider: PRumoProvider()) { entry in
            PRumoWidgetView(entry: entry)
        }
        .configurationDisplayName(WidgetText.displayName)
        .description(WidgetText.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
