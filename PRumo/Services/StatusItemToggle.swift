import AppKit

@MainActor
enum StatusItemToggle {
    static func toggle() -> Bool {
        guard let button = statusBarButton() else { return false }
        NSApp.activate()
        button.performClick(nil)
        return true
    }

    private static func statusBarButton() -> NSStatusBarButton? {
        NSApp.windows
            .filter { NSStringFromClass(type(of: $0)).contains(AppConstants.statusBarWindowClass) }
            .lazy
            .compactMap { $0.contentView.flatMap(findButton) }
            .first
    }

    private static func findButton(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = findButton(in: subview) { return button }
        }
        return nil
    }
}
