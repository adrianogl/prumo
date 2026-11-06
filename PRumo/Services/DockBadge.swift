import AppKit

@MainActor
enum DockBadge {
    static func update(count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
    }
}
