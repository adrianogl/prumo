import Foundation

public struct GitHubClient: Sendable {
    private static let endpoint = URL(string: "https://api.github.com/graphql")!

    private let token: String
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date

    public init(
        token: String,
        transport: HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.token = token
        self.transport = transport
        self.now = now
    }

    public func fetchSnapshot() async throws(GitHubError) -> Snapshot {
        async let mine = result { () async throws(GitHubError) -> Data in try await search(Queries.mine) }
        async let review = result { () async throws(GitHubError) -> Data in try await search(Queries.review) }
        let mineData = try await mine.get()
        let reviewData = try await review.get()
        do {
            return try PullRequestMapper.snapshot(mineJSON: mineData, reviewJSON: reviewData, now: now())
        } catch {
            throw .graphQL(messages: ["Resposta inesperada do GitHub"])
        }
    }

    private func result(_ work: () async throws(GitHubError) -> Data) async -> Result<Data, GitHubError> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private func search(_ query: String) async throws(GitHubError) -> Data {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["query": Queries.searchQuery, "variables": ["q": query]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw .network
        }
        try check(response)
        try checkGraphQLErrors(data)
        return data
    }

    private func check(_ response: HTTPURLResponse) throws(GitHubError) {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw .unauthorized
        case 403, 429:
            if response.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0" || response.statusCode == 429 {
                let reset = response.value(forHTTPHeaderField: "x-ratelimit-reset")
                    .flatMap(TimeInterval.init)
                    .map { Date(timeIntervalSince1970: $0) }
                throw .rateLimited(resetAt: reset)
            }
            throw .server(status: response.statusCode)
        default:
            throw .server(status: response.statusCode)
        }
    }

    private func checkGraphQLErrors(_ data: Data) throws(GitHubError) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errors = object["errors"] as? [[String: Any]],
            !errors.isEmpty
        else { return }
        throw .graphQL(messages: errors.compactMap { $0["message"] as? String })
    }
}
