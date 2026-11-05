import Foundation

public struct GitHubClient: Sendable {
    private static let endpoint = URL(string: "https://api.github.com/graphql")!
    private static let restBase = "https://api.github.com"

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

    public func fetchSnapshot() async throws(ProviderError) -> Snapshot {
        let moment = now()
        async let mine = result { () async throws(ProviderError) -> Data in try await search(Queries.mine) }
        async let review = result { () async throws(ProviderError) -> Data in try await search(Queries.review) }
        async let merged = result { () async throws(ProviderError) -> Data in
            try await search(Queries.merged(since: moment, timeZone: .current), query: Queries.mergedSearchQuery)
        }
        let mineData = try await mine.get()
        let reviewData = try await review.get()
        let mergedData = try? await merged.get()
        do {
            return try PullRequestMapper.snapshot(mineJSON: mineData, reviewJSON: reviewData, mergedJSON: mergedData, now: moment)
        } catch {
            throw .unexpectedResponse
        }
    }

    private func result(_ work: () async throws(ProviderError) -> Data) async -> Result<Data, ProviderError> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    public func pullRequestStates(ids: [String]) async throws(ProviderError) -> [String: PRState] {
        guard !ids.isEmpty else { return [:] }
        let data = try await post(query: Queries.states, variables: ["ids": ids])
        do {
            let decoded = try JSONDecoder().decode(StatesResponse.self, from: data)
            var states: [String: PRState] = [:]
            for node in decoded.data.nodes.compactMap(\.value) {
                if let state = PRState(rawValue: node.state) { states[node.id] = state }
            }
            return states
        } catch {
            throw .unexpectedResponse
        }
    }

    public func viewerLogin() async throws(ProviderError) -> String {
        let data = try await post(query: Queries.viewer, variables: [:])
        do {
            return try JSONDecoder().decode(ViewerResponse.self, from: data).data.viewer.login
        } catch {
            throw .unexpectedResponse
        }
    }

    public func rerunFailedJobs(repository: String, runID: Int) async throws(ProviderError) {
        guard let url = URL(string: "\(Self.restBase)/repos/\(repository)/actions/runs/\(runID)/rerun-failed-jobs") else {
            throw .unexpectedResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        _ = try await send(request)
    }

    private func search(_ term: String, query document: String = Queries.searchQuery) async throws(ProviderError) -> Data {
        try await post(query: document, variables: ["q": term])
    }

    private func post(query: String, variables: [String: Any]) async throws(ProviderError) -> Data {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["query": query, "variables": variables]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data = try await send(request)
        try checkGraphQLErrors(data)
        return data
    }

    private func send(_ original: URLRequest) async throws(ProviderError) -> Data {
        var request = original
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw .network
        }
        try check(response)
        return data
    }

    private func check(_ response: HTTPURLResponse) throws(ProviderError) {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw .unauthorized
        case 403, 429:
            if let retryAfter = response.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init) {
                throw .rateLimited(resetAt: now().addingTimeInterval(retryAfter))
            }
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

    private func checkGraphQLErrors(_ data: Data) throws(ProviderError) {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errors = object["errors"] as? [[String: Any]],
            !errors.isEmpty,
            object["data"] is NSNull || object["data"] == nil
        else { return }
        throw .graphQL(messages: errors.compactMap { $0["message"] as? String })
    }
}

private struct StatesResponse: Decodable {
    let data: DataNode

    struct DataNode: Decodable {
        let nodes: [LossyNode<StateNode>]
    }

    struct StateNode: Decodable {
        let id: String
        let state: String
    }
}
