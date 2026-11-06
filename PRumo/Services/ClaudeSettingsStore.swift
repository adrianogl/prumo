import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class ClaudeSettingsStore {
    var settings: ClaudeSettings {
        didSet { persist() }
    }
    var scanned: [String: [URL]] = [:]
    var isScanning = false

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let home: String
    @ObservationIgnored private var scanGeneration = 0

    init(defaults: UserDefaults = .standard, home: String = NSHomeDirectory()) {
        self.defaults = defaults
        self.home = home
        let stored = defaults.data(forKey: AppConstants.claudeSettingsKey)
            .flatMap { try? JSONDecoder().decode(ClaudeSettings.self, from: $0) }
        settings = stored ?? Self.firstRunSettings(defaults)
        if stored == nil { persist() }
    }

    private static func firstRunSettings(_ defaults: UserDefaults) -> ClaudeSettings {
        var settings = ClaudeSettings.defaults
        if !defaults.bool(forKey: AppConstants.onboardingDoneKey) { settings.terminal = .embedded }
        return settings
    }

    var overrides: [String: URL] {
        settings.cloneOverrides.mapValues { URL(fileURLWithPath: expand($0)) }
    }

    var repositories: [String] {
        Set(scanned.keys).union(settings.cloneOverrides.keys).sorted()
    }

    func resolvedCount(of repositories: Set<String>) -> Int {
        Set(repositories.map { $0.lowercased() })
            .filter { CloneResolver.pick(repository: $0, scanned: scanned, overrides: overrides) != nil }
            .count
    }

    func rescan(gitlabHosts: Set<String> = []) async {
        scanGeneration += 1
        let generation = scanGeneration
        isScanning = true
        let root = URL(fileURLWithPath: expand(settings.clonesRoot))
        let result = await Task.detached {
            await CloneLocator(
                root: root, fileSystem: LocalFileSystem(), runner: SystemProcessRunner(), gitlabHosts: gitlabHosts
            ).scan()
        }.value
        guard generation == scanGeneration else { return }
        scanned = result
        isScanning = false
    }

    func setOverride(repository: String, path: URL) {
        settings.cloneOverrides[repository.lowercased()] = abbreviate(path.path)
    }

    func removeOverride(repository: String) {
        settings.cloneOverrides.removeValue(forKey: repository.lowercased())
    }

    func setClonesRoot(_ url: URL) {
        settings.clonesRoot = abbreviate(url.path)
    }

    func setWorktreesRoot(_ url: URL) {
        settings.worktreesRoot = abbreviate(url.path)
    }

    func abbreviate(_ path: String) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    func expand(_ path: String) -> String {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home + path.dropFirst(1) }
        return path
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: AppConstants.claudeSettingsKey)
    }
}
