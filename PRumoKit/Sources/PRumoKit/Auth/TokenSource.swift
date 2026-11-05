public protocol TokenStore: Sendable {
    func read() -> String?
    func write(_ token: String) throws
    func delete() throws
}

public enum TokenOrigin: String, Codable, Sendable {
    case ghCLI
    case pasted
}
