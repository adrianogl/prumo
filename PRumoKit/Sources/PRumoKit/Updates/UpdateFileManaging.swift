import Foundation

public protocol UpdateFileManaging: Sendable {
    func isWritable(_ url: URL) -> Bool
    func exists(_ url: URL) -> Bool
    func infoDictionary(ofApp url: URL) -> [String: String]?
    func createDirectory(_ url: URL) throws
    func write(_ data: Data, to url: URL) throws
    func copyItem(at source: URL, to destination: URL) throws
    func replaceItem(at original: URL, with replacement: URL) throws
    func removeItem(_ url: URL)
}
