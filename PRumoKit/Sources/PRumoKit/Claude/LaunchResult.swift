import Foundation

public struct LaunchResult: Sendable, Equatable {
    public let directory: URL
    public let clone: URL
    public let embeddedScript: URL?

    public init(directory: URL, clone: URL, embeddedScript: URL? = nil) {
        self.directory = directory
        self.clone = clone
        self.embeddedScript = embeddedScript
    }
}
