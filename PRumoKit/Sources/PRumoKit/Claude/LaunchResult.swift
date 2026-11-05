import Foundation

public struct LaunchResult: Sendable, Equatable {
    public let directory: URL
    public let clone: URL

    public init(directory: URL, clone: URL) {
        self.directory = directory
        self.clone = clone
    }
}
