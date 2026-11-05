import SwiftUI
import AppKit
import PRumoKit

struct MenuBarLabel: View {
    let model: AppModel

    private var reviewCount: Int { model.snapshot?.toReview.count ?? 0 }
    private var hasFailure: Bool {
        model.snapshot?.mine.contains { if case .failure = $0.ci { true } else { false } } ?? false
    }

    var body: some View {
        HStack(spacing: 3) {
            Image("MenuBarGlyph")
                .resizable()
                .scaledToFit()
                .frame(width: PopoverMetrics.menuBarGlyphSize, height: PopoverMetrics.menuBarGlyphSize)
            if reviewCount > 0 {
                Text("\(reviewCount)")
            }
            if hasFailure {
                Image(nsImage: Self.failureDot)
            }
        }
    }

    private static let failureDot: NSImage = {
        let size = NSSize(width: PopoverMetrics.menuBarDotSize, height: PopoverMetrics.menuBarDotSize)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }()
}
