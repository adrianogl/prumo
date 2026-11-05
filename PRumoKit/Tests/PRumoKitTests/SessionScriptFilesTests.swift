import Foundation
import Testing
@testable import PRumoKit

@Suite struct SessionScriptFilesTests {
    private func makeTemp() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("prumo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func mode(_ url: URL) throws -> Int {
        (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }

    @Test func writeCreatesFileAndDirWith0700() throws {
        let root = try makeTemp()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions")
        let file = sessions.appendingPathComponent("a.zsh")
        try SessionScriptFiles.write("echo oi\n", to: file)
        #expect(try mode(file) == 0o700)
        #expect(try mode(sessions) == 0o700)
        #expect(try String(contentsOf: file, encoding: .utf8) == "echo oi\n")
    }

    @Test func writeTightensExistingDirectory() throws {
        let root = try makeTemp()
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(
            at: sessions, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        let file = sessions.appendingPathComponent("a.zsh")
        try SessionScriptFiles.write("one\n", to: file)
        try SessionScriptFiles.write("two\n", to: file)
        #expect(try mode(sessions) == 0o700)
        #expect(try mode(file) == 0o700)
        #expect(try String(contentsOf: file, encoding: .utf8) == "two\n")
        #expect(try FileManager.default.contentsOfDirectory(atPath: sessions.path) == ["a.zsh"])
    }

    @Test func cleanupRemovesOnlyOldZshFiles() throws {
        let root = try makeTemp()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date()
        let old = now.addingTimeInterval(-2 * 86_400)
        let oldZsh = root.appendingPathComponent("old.zsh")
        let newZsh = root.appendingPathComponent("new.zsh")
        let oldTxt = root.appendingPathComponent("old.txt")
        for url in [oldZsh, newZsh, oldTxt] { try "x".write(to: url, atomically: true, encoding: .utf8) }
        for url in [oldZsh, oldTxt] {
            try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: url.path)
        }
        SessionScriptFiles.cleanup(in: root, now: now)
        #expect(!FileManager.default.fileExists(atPath: oldZsh.path))
        #expect(FileManager.default.fileExists(atPath: newZsh.path))
        #expect(FileManager.default.fileExists(atPath: oldTxt.path))
    }
}
