import AppKit
import PRumoKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        let allowedHosts = Self.allowedHosts()
        for url in urls {
            guard let target = WidgetLink.target(from: url, allowedHosts: allowedHosts) else { continue }
            NSWorkspace.shared.open(target)
        }
    }

    private static func allowedHosts() -> Set<String> {
        let list = AccountList.decode(UserDefaults.standard.data(forKey: AppConstants.accountsKey))
        let gitlabHosts = (list?.accounts ?? [])
            .filter { $0.provider == .gitlab }
            .map { $0.host.lowercased() }
        return Set([AccountConstants.githubHost] + gitlabHosts)
    }
}
