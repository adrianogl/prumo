struct GitLabUser: Decodable, Equatable, Sendable {
    let username: String
    let bot: Bool?
}
