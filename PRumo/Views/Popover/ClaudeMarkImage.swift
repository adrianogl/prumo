import AppKit
import SwiftUI

enum ClaudeMarkImage {
    @MainActor static let menuIcon: NSImage = {
        let side = ClaudeMetrics.menuIconSize
        let source = NSImage(named: ClaudeSymbol.mark)
        let tint = NSColor(Color.claudeMark)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            source?.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }()
}
