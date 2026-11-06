import AppKit
import Observation

@Observable @MainActor
final class MainWindowPresence {
    private(set) var isOpen = false
    @ObservationIgnored var opener: (() -> Void)?

    func open() {
        NSApp.setActivationPolicy(.regular)
        opener?()
        NSApp.activate()
    }

    func didOpen() {
        isOpen = true
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func didClose() {
        isOpen = false
        DockBadge.update(count: 0)
        NSApp.setActivationPolicy(.accessory)
    }
}
