import Foundation

public struct UpdateInstaller: Sendable {
    private let runner: ProcessRunner
    private let transport: HTTPTransport
    private let files: UpdateFileManaging

    public init(runner: ProcessRunner, transport: HTTPTransport = URLSessionTransport(), files: UpdateFileManaging = LocalUpdateFileManager()) {
        self.runner = runner
        self.transport = transport
        self.files = files
    }

    public func install(
        _ release: ReleaseInfo, replacing appURL: URL, workDirectory: URL, processID: Int32
    ) async throws(UpdateInstallError) {
        guard let dmgURL = release.dmgURL, let checksumURL = release.checksumURL else { throw .notInstallable }
        let folder = appURL.deletingLastPathComponent()
        guard files.isWritable(folder), files.isWritable(appURL) else { throw .notWritable }

        defer { files.removeItem(workDirectory) }
        let dmg = try await download(dmgURL)
        let checksum = String(decoding: try await download(checksumURL), as: UTF8.self)
        guard UpdateVerifier.matches(dmg, checksum: checksum) else { throw .checksumMismatch }

        let image = workDirectory.appendingPathComponent(UpdateConstants.dmgAssetName)
        let mount = workDirectory.appendingPathComponent(UpdateConstants.mountDirectoryName)
        do {
            try files.createDirectory(mount)
            try files.write(dmg, to: image)
        } catch {
            throw .downloadFailed
        }

        let staging = folder.appendingPathComponent("\(UpdateConstants.stagingPrefix)\(release.version).app")
        try await attach(image, at: mount)
        let copied = copy(from: mount.appendingPathComponent(UpdateConstants.appBundleName), to: staging)
        _ = try? await runner.run(UpdateConstants.hdiutil, ["detach", mount.path, "-force"])
        guard copied else {
            files.removeItem(staging)
            throw .copyFailed
        }

        guard packageMatches(staging, release: release, current: appURL) else {
            files.removeItem(staging)
            throw .packageMismatch
        }

        do {
            try files.replaceItem(at: appURL, with: staging)
        } catch {
            files.removeItem(staging)
            throw .replaceFailed
        }

        _ = try? await runner.run(UpdateConstants.xattr, ["-dr", UpdateConstants.quarantineAttribute, appURL.path])
        try await relaunch(appURL, after: processID)
    }

    private func download(_ url: URL) async throws(UpdateInstallError) -> Data {
        do {
            let (data, response) = try await transport.send(URLRequest(url: url))
            guard (200..<300).contains(response.statusCode) else { throw UpdateInstallError.downloadFailed }
            return data
        } catch {
            throw .downloadFailed
        }
    }

    private func packageMatches(_ staged: URL, release: ReleaseInfo, current: URL) -> Bool {
        guard let candidate = files.infoDictionary(ofApp: staged),
              let identifier = files.infoDictionary(ofApp: current)?[UpdateConstants.bundleIdentifierKey],
              candidate[UpdateConstants.bundleIdentifierKey] == identifier,
              let version = candidate[UpdateConstants.shortVersionKey].flatMap(AppVersion.init)
        else { return false }
        return version == release.version
    }

    private func attach(_ image: URL, at mount: URL) async throws(UpdateInstallError) {
        let result = try? await runner.run(
            UpdateConstants.hdiutil, ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, image.path])
        guard result?.status == 0 else { throw .mountFailed }
    }

    private func copy(from source: URL, to staging: URL) -> Bool {
        guard files.exists(source) else { return false }
        files.removeItem(staging)
        do {
            try files.copyItem(at: source, to: staging)
            return true
        } catch {
            return false
        }
    }

    private func relaunch(_ appURL: URL, after processID: Int32) async throws(UpdateInstallError) {
        let result = try? await runner.run(
            UpdateConstants.shell, ["-c", UpdateConstants.relaunchScript, "sh", "\(processID)", appURL.path])
        guard result?.status == 0 else { throw .relaunchFailed }
    }
}
