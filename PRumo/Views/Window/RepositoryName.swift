import Foundation

enum RepositoryName {
    static func short(_ key: String) -> String {
        key.split(separator: "/").last.map(String.init) ?? key
    }
}
