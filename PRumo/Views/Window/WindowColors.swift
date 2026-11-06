import AppKit
import SwiftUI

extension Color {
    static let windowSidebar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x2b / 255, green: 0x27 / 255, blue: 0x23 / 255, alpha: 1)
            : NSColor(srgbRed: 0xef / 255, green: 0xe6 / 255, blue: 0xd6 / 255, alpha: 1)
    })

    static let windowCard = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x2e / 255, green: 0x2b / 255, blue: 0x28 / 255, alpha: 1)
            : NSColor(srgbRed: 0xff / 255, green: 0xfd / 255, blue: 0xf9 / 255, alpha: 1)
    })

    static let windowLine = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x3a / 255, green: 0x36 / 255, blue: 0x33 / 255, alpha: 1)
            : NSColor(srgbRed: 0xe3 / 255, green: 0xd8 / 255, blue: 0xc5 / 255, alpha: 1)
    })
}
