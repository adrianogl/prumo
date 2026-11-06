import SwiftUI
import AppKit
import PRumoKit

struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    @AppStorage(AppConstants.openWindowAtLaunchKey) private var openWindowAtLaunch = false

    private var reviewCount: Int { model.reviewBadgeCount }
    private var hasFailure: Bool { model.snapshot.map(Counters.hasFailingCI) ?? false }

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: Self.glyph)
            if reviewCount > 0 {
                Text("\(reviewCount)")
            }
            if hasFailure {
                Image(nsImage: Self.failureDot)
            }
        }
        .task {
            model.mainWindow.opener = { openWindow(id: MainWindowText.id) }
            if openWindowAtLaunch, !model.needsOnboarding { model.mainWindow.open() }
        }
        .onChange(of: model.needsOnboarding, initial: true) {
            if model.needsOnboarding {
                openWindow(id: OnboardingText.id)
                NSApp.activate()
            }
        }
    }

    private static let glyph: NSImage = {
        let side = PopoverMetrics.menuBarGlyphSize
        let source = NSImage(named: PopoverSymbol.menuBarGlyph)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            source?.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }()

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
