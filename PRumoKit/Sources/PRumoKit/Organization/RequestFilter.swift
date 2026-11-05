public enum RequestFilter: String, Codable, CaseIterable, Sendable {
    case forYou, forTeam, stale
}
