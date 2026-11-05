import Foundation
import Testing
@testable import PRumoKit

@Suite struct ClaudeSettingsTests {
    @Test func decodesPartialJSONWithDefaults() throws {
        let json = #"{"extraFlags":"--model opus","removeWorktreeOnClose":false}"#
        let settings = try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
        #expect(settings.extraFlags == "--model opus")
        #expect(settings.removeWorktreeOnClose == false)
        #expect(settings.reviewTemplate == ClaudeDefaults.reviewTemplate)
        #expect(settings.ciTemplate == ClaudeDefaults.ciTemplate)
        #expect(settings.conflictTemplate == ClaudeDefaults.conflictTemplate)
        #expect(settings.terminal == ClaudeDefaults.terminal)
        #expect(settings.clonesRoot == ClaudeDefaults.clonesRoot)
        #expect(settings.worktreesRoot == ClaudeDefaults.worktreesRoot)
        #expect(settings.cloneOverrides.isEmpty)
    }

    @Test func decodesEmptyObjectAsDefaults() throws {
        let settings = try JSONDecoder().decode(ClaudeSettings.self, from: Data("{}".utf8))
        #expect(settings == ClaudeSettings.defaults)
    }

    @Test func roundTrips() throws {
        let original = ClaudeSettings(terminal: .custom(template: "x {dir} {cmd}"), cloneOverrides: ["a/b": "~/x"])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(ClaudeSettings.self, from: data) == original)
    }
}
