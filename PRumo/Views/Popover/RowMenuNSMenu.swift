import AppKit
import PRumoKit

@MainActor
enum RowMenuNSMenu {
    static func show(entries: [RowMenuEntry], isRerunning: Bool, at point: NSPoint, in view: NSView, perform: @escaping (RowMenuEntry) -> Void) {
        let handler = Handler()
        let menu = NSMenu()
        for (index, entry) in entries.enumerated() {
            menu.addItem(item(for: entry, tag: index, isRerunning: isRerunning, handler: handler))
        }
        menu.popUp(positioning: nil, at: point, in: view)
        guard let chosen = handler.chosenTag, entries.indices.contains(chosen) else { return }
        perform(entries[chosen])
    }

    private static func item(for entry: RowMenuEntry, tag: Int, isRerunning: Bool, handler: Handler) -> NSMenuItem {
        if entry == .separator { return NSMenuItem.separator() }
        let item = NSMenuItem(title: entry.title, action: #selector(Handler.choose(_:)), keyEquivalent: entry.menuKeyEquivalent)
        item.keyEquivalentModifierMask = entry.menuKeyModifiers
        item.target = handler
        item.tag = tag
        if case .rerunFailedJobs = entry { item.isEnabled = !isRerunning }
        if case .claude = entry { item.image = ClaudeMarkImage.menuIcon }
        return item
    }

    private final class Handler: NSObject {
        var chosenTag: Int?

        @objc func choose(_ sender: NSMenuItem) {
            chosenTag = sender.tag
        }
    }
}
