import Foundation
import Testing
@testable import PRumoKit

private func releaseResponse(_ status: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: UpdateConstants.latestReleaseURL, statusCode: status, httpVersion: nil, headerFields: [:])!
}

private func releaseJSON(tag: String, assets: [String] = ["PRumo.dmg", "PRumo.dmg.sha256"], body: String? = "- feat: novidade") -> Data {
    var object: [String: Any] = [
        "tag_name": tag,
        "html_url": "https://github.com/adrianogl/prumo/releases/tag/\(tag)",
        "assets": assets.map { name in
            ["name": name, "browser_download_url": "https://github.com/adrianogl/prumo/releases/download/\(tag)/\(name)"]
        },
    ]
    if let body { object["body"] = body }
    return try! JSONSerialization.data(withJSONObject: object)
}

private func checker(installed: String, status: Int = 200, data: Data = Data()) -> (UpdateChecker, FakeTransport) {
    let transport = FakeTransport { _ in (data, releaseResponse(status)) }
    return (UpdateChecker(installed: AppVersion(installed)!, transport: transport), transport)
}

@Suite struct AppVersionTests {
    @Test func parsesPlainAndPrefixedVersions() {
        #expect(AppVersion("0.2.0") == AppVersion(major: 0, minor: 2, patch: 0))
        #expect(AppVersion("v1.10.3") == AppVersion(major: 1, minor: 10, patch: 3))
        #expect(AppVersion(" v0.3.0\n") == AppVersion(major: 0, minor: 3, patch: 0))
    }

    @Test func rejectsInvalidVersions() {
        #expect(AppVersion("1.2") == nil)
        #expect(AppVersion("1.2.3.4") == nil)
        #expect(AppVersion("1.2.x") == nil)
        #expect(AppVersion("") == nil)
        #expect(AppVersion("1.-2.3") == nil)
    }

    @Test func comparesNumerically() {
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.0")!)
        #expect(AppVersion("1.0.0")! > AppVersion("0.99.99")!)
        #expect(AppVersion("0.2.1")! > AppVersion("0.2.0")!)
        #expect(!(AppVersion("0.2.0")! < AppVersion("0.2.0")!))
    }

    @Test func describesWithoutPrefix() {
        #expect(AppVersion("v0.3.0")!.description == "0.3.0")
    }
}

@Suite struct UpdateCheckerTests {
    @Test func returnsNewerRelease() async throws {
        let (checker, transport) = checker(installed: "0.2.0", data: releaseJSON(tag: "v0.3.0"))
        let release = try #require(try await checker.check())
        #expect(release.version == AppVersion("0.3.0"))
        #expect(release.notes == "- feat: novidade")
        #expect(release.pageURL.absoluteString == "https://github.com/adrianogl/prumo/releases/tag/v0.3.0")
        #expect(release.dmgURL?.lastPathComponent == "PRumo.dmg")
        #expect(release.checksumURL?.lastPathComponent == "PRumo.dmg.sha256")
        #expect(release.isInstallable)
        #expect(transport.requests.first?.url == UpdateConstants.latestReleaseURL)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }

    @Test func ignoresSameVersion() async throws {
        let (checker, _) = checker(installed: "0.3.0", data: releaseJSON(tag: "v0.3.0"))
        #expect(try await checker.check() == nil)
    }

    @Test func ignoresOlderVersion() async throws {
        let (checker, _) = checker(installed: "0.10.0", data: releaseJSON(tag: "v0.9.0"))
        #expect(try await checker.check() == nil)
    }

    @Test func releaseWithoutDMGIsNotInstallable() async throws {
        let (checker, _) = checker(installed: "0.2.0", data: releaseJSON(tag: "v0.3.0", assets: ["PRumo.dmg.sha256"]))
        let release = try #require(try await checker.check())
        #expect(release.dmgURL == nil)
        #expect(!release.isInstallable)
    }

    @Test func releaseWithoutChecksumIsNotInstallable() async throws {
        let (checker, _) = checker(installed: "0.2.0", data: releaseJSON(tag: "v0.3.0", assets: ["PRumo.dmg"]))
        let release = try #require(try await checker.check())
        #expect(!release.isInstallable)
    }

    @Test func toleratesMissingBodyAndAssets() async throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "tag_name": "v0.3.0", "html_url": "https://github.com/adrianogl/prumo/releases/tag/v0.3.0",
            "body": NSNull(),
        ])
        let (checker, _) = checker(installed: "0.2.0", data: data)
        let release = try #require(try await checker.check())
        #expect(release.notes == "")
        #expect(!release.isInstallable)
    }

    @Test func noReleaseReturnsNil() async throws {
        let (checker, _) = checker(installed: "0.2.0", status: 404)
        #expect(try await checker.check() == nil)
    }

    @Test func serverErrorIsMapped() async {
        let (checker, _) = checker(installed: "0.2.0", status: 500)
        await #expect(throws: UpdateError.server(status: 500)) { try await checker.check() }
    }

    @Test func rateLimitIsMapped() async {
        let (checker, _) = checker(installed: "0.2.0", status: 403)
        await #expect(throws: UpdateError.rateLimited) { try await checker.check() }
    }

    @Test func networkFailureIsMapped() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        let checker = UpdateChecker(installed: AppVersion("0.2.0")!, transport: transport)
        await #expect(throws: UpdateError.network) { try await checker.check() }
    }

    @Test func invalidTagIsUnexpected() async {
        let (checker, _) = checker(installed: "0.2.0", data: releaseJSON(tag: "nightly"))
        await #expect(throws: UpdateError.unexpectedResponse) { try await checker.check() }
    }

    @Test func invalidJSONIsUnexpected() async {
        let (checker, _) = checker(installed: "0.2.0", data: Data("<html>".utf8))
        await #expect(throws: UpdateError.unexpectedResponse) { try await checker.check() }
    }
}

@Suite struct UpdateVerifierTests {
    private let content = Data("PRumo".utf8)
    private let hash = "dbe754c25c043350f9b67af683dc4ac3d559403c512aa801d10481b8aa98df5a"

    @Test func acceptsMatchingHashIgnoringCaseAndWhitespace() {
        #expect(UpdateVerifier.sha256(of: content) == hash)
        #expect(UpdateVerifier.matches(content, checksum: hash))
        #expect(UpdateVerifier.matches(content, checksum: "  \(hash.uppercased())\n"))
        #expect(UpdateVerifier.matches(content, checksum: "\(hash)  PRumo.dmg\n"))
    }

    @Test func rejectsWrongHash() {
        #expect(!UpdateVerifier.matches(content, checksum: String(repeating: "0", count: 64)))
        #expect(!UpdateVerifier.matches(content, checksum: ""))
    }

    @Test func verifiesFileOnDisk() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("prumo-verifier-\(UUID().uuidString)")
        try content.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(UpdateVerifier.matches(fileAt: url, checksum: hash))
        #expect(!UpdateVerifier.matches(fileAt: url, checksum: String(repeating: "f", count: 64)))
        #expect(!UpdateVerifier.matches(fileAt: url.appendingPathExtension("nada"), checksum: hash))
    }
}
