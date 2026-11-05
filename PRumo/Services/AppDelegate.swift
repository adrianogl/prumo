import AppKit
import PRumoKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let target = WidgetLink.target(from: url) else { continue }
            NSWorkspace.shared.open(target)
        }
    }
}
