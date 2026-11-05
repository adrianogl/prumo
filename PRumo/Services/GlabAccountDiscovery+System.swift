import Foundation
import PRumoKit

extension GlabAccountDiscovery {
    static func system() -> GlabAccountDiscovery {
        GlabAccountDiscovery(
            runner: SystemProcessRunner(),
            environment: ProcessInfo.processInfo.environment,
            home: FileManager.default.homeDirectoryForCurrentUser,
            readFile: { try? String(contentsOf: $0, encoding: .utf8) },
            fileExists: { FileManager.default.isExecutableFile(atPath: $0) })
    }
}
