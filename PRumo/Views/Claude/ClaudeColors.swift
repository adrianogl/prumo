import AppKit
import SwiftUI

extension Color {
    static let claudeMark = Color(nsColor: NSColor(srgbRed: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255, alpha: 1))

    static let claudeButtonBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x3a / 255, green: 0x2a / 255, blue: 0x22 / 255, alpha: 1)
            : NSColor(srgbRed: 0xff / 255, green: 0xf3 / 255, blue: 0xec / 255, alpha: 1)
    })

    static let claudeButtonText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0xe8 / 255, green: 0xa4 / 255, blue: 0x87 / 255, alpha: 1)
            : NSColor(srgbRed: 0xa4 / 255, green: 0x49 / 255, blue: 0x2c / 255, alpha: 1)
    })
}
