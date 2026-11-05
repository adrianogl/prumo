public enum KeyboardSelection {
    public static func move(from current: String?, in ids: [String], direction: MoveDirection) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else {
            return direction == .down ? ids.first : ids.last
        }
        switch direction {
        case .down: return ids[min(index + 1, ids.count - 1)]
        case .up: return ids[max(index - 1, 0)]
        }
    }

    public static func validated(_ current: String?, in ids: [String]) -> String? {
        guard let current, ids.contains(current) else { return nil }
        return current
    }
}
