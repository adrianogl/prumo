import AppKit
import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class UpdateStore {
    let installed: AppVersion?
    private(set) var status: UpdateStatus = .idle
    private(set) var lastCheck: Date?
    private(set) var installing = false
    var installError: UpdateInstallError?
    var autoCheck: Bool {
        didSet {
            defaults.set(autoCheck, forKey: AppConstants.updateAutoCheckKey)
            schedule()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, notifications: NotificationService, bundle: Bundle = .main) {
        self.defaults = defaults
        self.notifications = notifications
        installed = (bundle.object(forInfoDictionaryKey: AppConstants.shortVersionInfoKey) as? String).flatMap(AppVersion.init)
        autoCheck = defaults.object(forKey: AppConstants.updateAutoCheckKey) as? Bool ?? true
        lastCheck = defaults.object(forKey: AppConstants.updateLastCheckKey) as? Date
    }

    var available: ReleaseInfo? {
        if case .available(let release) = status { return release }
        return nil
    }

    func start() {
        schedule()
    }

    func checkNow() {
        Task { await check(notify: false) }
    }

    func install() {
        guard let release = available, release.isInstallable, !installing else { return }
        installing = true
        let installer = UpdateInstaller(runner: SystemProcessRunner(timeout: AppConstants.updateCommandTimeout))
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConstants.updateWorkDirectoryPrefix)\(UUID().uuidString)")
        let appURL = Bundle.main.bundleURL
        let processID = ProcessInfo.processInfo.processIdentifier
        Task {
            do throws(UpdateInstallError) {
                try await installer.install(release, replacing: appURL, workDirectory: work, processID: processID)
                NSApp.terminate(nil)
            } catch {
                installing = false
                installError = error
            }
        }
    }

    func openReleasePage() {
        guard let release = available else { return }
        NSWorkspace.shared.open(release.pageURL)
    }

    private func schedule() {
        loop?.cancel()
        loop = nil
        guard autoCheck else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check(notify: true)
                try? await Task.sleep(for: AppConstants.updateCheckInterval)
            }
        }
    }

    private func check(notify: Bool) async {
        guard status != .checking else { return }
        guard let installed else {
            status = .failed
            return
        }
        status = .checking
        do throws(UpdateError) {
            if let release = try await UpdateChecker(installed: installed).check() {
                status = .available(release)
                if notify { notifyOnce(release) }
            } else {
                status = .upToDate
            }
        } catch {
            status = .failed
        }
        let now = Date.now
        lastCheck = now
        defaults.set(now, forKey: AppConstants.updateLastCheckKey)
    }

    private func notifyOnce(_ release: ReleaseInfo) {
        let version = release.version.description
        guard defaults.string(forKey: AppConstants.updateNotifiedVersionKey) != version else { return }
        defaults.set(version, forKey: AppConstants.updateNotifiedVersionKey)
        notifications.postUpdate(version: version, url: release.pageURL)
    }
}
