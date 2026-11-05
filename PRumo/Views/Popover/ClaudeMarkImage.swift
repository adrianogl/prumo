import AppKit

enum ClaudeMarkImage {
    @MainActor static let menuIcon: NSImage = {
        let image = (NSImage(named: ClaudeSymbol.mark)?.copy() as? NSImage) ?? NSImage()
        image.isTemplate = false
        image.size = NSSize(width: ClaudeMetrics.menuIconSize, height: ClaudeMetrics.menuIconSize)
        return image
    }()
}
