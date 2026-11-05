import AppKit
import SwiftUI

extension Color {
    static let prumoSand = Color(red: 0xf3 / 255, green: 0xe6 / 255, blue: 0xcf / 255)
    static let prumoSandDeep = Color(red: 0xd9 / 255, green: 0xc3 / 255, blue: 0xa0 / 255)
    static let prumoCharcoal = Color(red: 0x2a / 255, green: 0x26 / 255, blue: 0x22 / 255)
    static let prumoCaramel = Color(red: 0xa5 / 255, green: 0x71 / 255, blue: 0x3a / 255)

    static let prumoPopoverBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x25 / 255, green: 0x23 / 255, blue: 0x22 / 255, alpha: 1)
            : NSColor(srgbRed: 0xfb / 255, green: 0xf8 / 255, blue: 0xf2 / 255, alpha: 1)
    })
}

extension Color {
    static let prumoBadgeBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x34 / 255, green: 0x30 / 255, blue: 0x2d / 255, alpha: 1)
            : NSColor(srgbRed: 0xef / 255, green: 0xe6 / 255, blue: 0xd6 / 255, alpha: 1)
    })
}

extension Color {
    static let jiraBlue = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0x57 / 255, green: 0x9d / 255, blue: 0xff / 255, alpha: 1)
            : NSColor(srgbRed: 0x0c / 255, green: 0x66 / 255, blue: 0xe4 / 255, alpha: 1)
    })
}
