public struct FilterChip: Equatable, Sendable {
    public let key: FilterChipKey
    public let label: String

    public init(key: FilterChipKey, label: String) {
        self.key = key
        self.label = label
    }
}
