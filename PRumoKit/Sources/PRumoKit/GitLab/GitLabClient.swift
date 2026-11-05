import Foundation

public struct GitLabClient: AccountClient {
    private static let stateLimit = 20
    private static let mergeStatusField = "detailedMergeStatus"
    private static let reviewStateFields = ["mergeRequestInteraction", "reviewState"]
    private static let missingFieldMarker = "exist"
    private static let restStates: [String: PRState] = ["opened": .open, "closed": .closed, "merged": .merged]

    private let host: String
    private let token: String
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date
    private let cache: GitLabCapabilityCache

    public init(
        host: String,
        token: String,
        transport: HTTPTransport = URLSessionTransport(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.init(host: host, token: token, transport: transport, now: now, cache: GitLabCapabilityCache())
    }

    private init(
        host: String,
        token: String,
        transport: HTTPTransport,
        now: @escaping @Sendable () -> Date,
        cache: GitLabCapabilityCache
    ) {
        self.host = host.lowercased()
        self.token = token
        self.transport = transport
        self.now = now
        self.cache = cache
    }

    public func replacingToken(_ token: String) -> GitLabClient {
        GitLabClient(host: host, token: token, transport: transport, now: now, cache: cache)
    }

    public func currentUsername() async throws(ProviderError) -> String {
        let data = try await post(query: GitLabQueries.currentUser, variables: [:])
        let decoded: CurrentUserResponse
        do {
            decoded = try JSONDecoder().decode(CurrentUserResponse.self, from: data)
        } catch {
            throw .unexpectedResponse
        }
        guard let user = decoded.data.currentUser else { throw .unauthorized }
        return user.username
    }

    public func capabilities() async -> GitLabCapabilities {
        await cache.current
    }

    public func tokenScopes() async -> [String]? {
        do throws(ProviderError) {
            let data = try await get(path: "/api/v4/personal_access_tokens/self")
            return try? JSONDecoder().decode(PersonalTokenResponse.self, from: data).scopes
        } catch .server(status: 400) {
            guard let data = try? await get(path: "/oauth/token/info") else { return nil }
            return try? JSONDecoder().decode(OAuthTokenInfo.self, from: data).scopes
        } catch {
            return nil
        }
    }

    public func fetchSnapshot() async throws(ProviderError) -> Snapshot {
        let moment = now()
        let capabilities = await cache.current
        do throws(ProviderError) {
            return try await snapshot(capabilities: capabilities, at: moment)
        } catch .graphQL(let messages) {
            let reduced = Self.dropping(messages, from: capabilities)
            guard reduced != capabilities else { throw .graphQL(messages: messages) }
            await cache.update(reduced)
            return try await snapshot(capabilities: reduced, at: moment)
        }
    }

    public func pullRequestStates(ids: [String]) async throws(ProviderError) -> [String: PRState] {
        let targets = ids.compactMap { id -> (id: String, projectID: Int, iid: Int)? in
            guard let parsed = GitLabID.parse(id), parsed.host == host else { return nil }
            return (id, parsed.projectID, parsed.iid)
        }.prefix(Self.stateLimit)
        return await withTaskGroup(of: (String, PRState?).self) { group in
            for target in targets {
                group.addTask { (target.id, await state(projectID: target.projectID, iid: target.iid)) }
            }
            var states: [String: PRState] = [:]
            for await (id, state) in group {
                if let state { states[id] = state }
            }
            return states
        }
    }

    public func rerunFailedJobs(pr: PullRequest) async throws(ProviderError) {
        throw .unexpectedResponse
    }

    private static func dropping(_ messages: [String], from capabilities: GitLabCapabilities) -> GitLabCapabilities {
        var reduced = capabilities
        for message in messages where message.contains(missingFieldMarker) {
            if message.contains(mergeStatusField) { reduced.hasDetailedMergeStatus = false }
            if reviewStateFields.contains(where: message.contains) { reduced.hasReviewState = false }
        }
        return reduced
    }

    private func snapshot(capabilities: GitLabCapabilities, at moment: Date) async throws(ProviderError) -> Snapshot {
        let data = try await post(
            query: GitLabQueries.snapshot(capabilities),
            variables: ["mergedAfter": GitLabQueries.mergedAfter(since: moment, timeZone: .current)]
        )
        do {
            return try MergeRequestMapper.snapshot(data, host: host, capabilities: capabilities, now: moment)
        } catch let error as ProviderError {
            throw error
        } catch {
            throw .unexpectedResponse
        }
    }

    private func state(projectID: Int, iid: Int) async -> PRState? {
        guard let data = try? await get(path: "/api/v4/projects/\(projectID)/merge_requests/\(iid)"),
              let decoded = try? JSONDecoder().decode(RESTMergeRequest.self, from: data) else { return nil }
        return Self.restStates[decoded.state]
    }

    private func url(_ path: String) throws(ProviderError) -> URL {
        guard let url = URL(string: "https://\(host)\(path)") else { throw .unexpectedResponse }
        return url
    }

    private func get(path: String) async throws(ProviderError) -> Data {
        var request = URLRequest(url: try url(path))
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post(query: String, variables: [String: String]) async throws(ProviderError) -> Data {
        var request = URLRequest(url: try url("/api/graphql"))
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
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        case 429:
            if let retryAfter = response.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init) {
                throw .rateLimited(resetAt: now().addingTimeInterval(retryAfter))
            }
            let reset = response.value(forHTTPHeaderField: "ratelimit-reset")
                .flatMap(TimeInterval.init)
                .map { Date(timeIntervalSince1970: $0) }
            throw .rateLimited(resetAt: reset)
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

private struct CurrentUserResponse: Decodable {
    let data: DataNode

    struct DataNode: Decodable {
        let currentUser: User?
    }

    struct User: Decodable {
        let username: String
    }
}

private struct PersonalTokenResponse: Decodable {
    let scopes: [String]
}

private struct OAuthTokenInfo: Decodable {
    let scopes: [String]

    private enum CodingKeys: String, CodingKey {
        case scope
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let list = try? container.decode([String].self, forKey: .scope) {
            scopes = list
        } else {
            scopes = try container.decode(String.self, forKey: .scope).split(separator: " ").map(String.init)
        }
    }
}

private struct RESTMergeRequest: Decodable {
    let state: String
}
