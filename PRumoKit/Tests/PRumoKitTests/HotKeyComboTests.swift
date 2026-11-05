import Foundation
import Testing
@testable import PRumoKit

struct HotKeyComboTests {
    @Test func standardIsOptionCommandP() {
        #expect(HotKeyCombo.standard.display == "⌥⌘P")
        #expect(HotKeyCombo.standard.keyCode == 35)
    }

    @Test func displayOrderMatchesMacConvention() {
        let combo = HotKeyCombo(keyCode: 40, key: "K", modifiers: [.command, .shift, .control])
        #expect(combo.display == "⌃⇧⌘K")
    }

    @Test func carbonFlags() {
        #expect(HotKeyCombo(keyCode: 35, key: "P", modifiers: [.option, .command]).carbonModifiers == 2304)
        #expect(HotKeyCombo(keyCode: 35, key: "P", modifiers: [.control, .shift]).carbonModifiers == 4608)
    }

    @Test func shiftOnlyIsInvalid() {
        #expect(!HotKeyCombo(keyCode: 35, key: "P", modifiers: [.shift]).isValid)
        #expect(!HotKeyCombo(keyCode: 35, key: "P", modifiers: []).isValid)
        #expect(HotKeyCombo.standard.isValid)
    }

    @Test func displayUsesCapturedKeyNotKeyCode() {
        let combo = HotKeyCombo(keyCode: 35, key: "Ç", modifiers: [.option, .command])
        #expect(combo.display == "⌥⌘Ç")
    }

    @Test func displayUppercasesKey() {
        let combo = HotKeyCombo(keyCode: 35, key: "p", modifiers: [.command])
        #expect(combo.display == "⌘P")
    }

    @Test func roundTripCodable() throws {
        let combo = HotKeyCombo(keyCode: 40, key: "K", modifiers: [.control, .command])
        let data = try JSONEncoder().encode(combo)
        #expect(try JSONDecoder().decode(HotKeyCombo.self, from: data) == combo)
    }

    @Test func decodesEmptyJSONAsStandard() throws {
        let decoded = try JSONDecoder().decode(HotKeyCombo.self, from: Data("{}".utf8))
        #expect(decoded == .standard)
    }

    @Test func decodesPartialJSONKeepingDefaults() throws {
        let decoded = try JSONDecoder().decode(HotKeyCombo.self, from: Data(#"{"keyCode":40,"key":"K"}"#.utf8))
        #expect(decoded.keyCode == 40)
        #expect(decoded.key == "K")
        #expect(decoded.modifiers == HotKeyCombo.standard.modifiers)
    }

    @Test func ignoresUnknownModifiers() throws {
        let json = #"{"keyCode":35,"key":"P","modifiers":["command","hyper"]}"#
        let decoded = try JSONDecoder().decode(HotKeyCombo.self, from: Data(json.utf8))
        #expect(decoded.modifiers == [.command])
    }
}
