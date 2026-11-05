import Foundation
import Testing
@testable import PRumoKit

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private let handler: @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { recorded.append(request) }
        return try handler(request)
    }
}

private func httpResponse(_ status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://api.github.com/graphql")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
}

private func variableQuery(_ request: URLRequest) -> String? {
    let object = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
    return (object?["variables"] as? [String: String])?["q"]
}

private func respond(_ request: URLRequest, mine: String = "search-mine") -> (Data, HTTPURLResponse) {
    let term = variableQuery(request)
    if term == Queries.mine { return (fixture(mine), httpResponse(200)) }
    if term == Queries.review { return (fixture("search-review"), httpResponse(200)) }
    return (fixture("search-merged"), httpResponse(200))
}

private func client(_ transport: FakeTransport) -> GitHubClient {
    GitHubClient(token: "t0k", transport: transport, now: { Date.fixed })
}

@Suite struct GitHubClientTests {
    @Test func fetchSnapshotSendsThreeSearches() async throws {
        let transport = FakeTransport { respond($0) }
        let snapshot = try await client(transport).fetchSnapshot()

        #expect(transport.requests.count == 3)
        for request in transport.requests {
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.github.com/graphql")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "bearer t0k")
        }
        let queries = Set(transport.requests.compactMap(variableQuery))
        #expect(queries == [Queries.mine, Queries.review, Queries.merged(since: .fixed, timeZone: .current)])
        #expect(snapshot.mergedToday.map(\.id) == ["PR_900", "PR_901"])
        #expect(snapshot.viewer == "adriano")
        #expect(snapshot.fetchedAt == Date.fixed)
        #expect(!snapshot.mine.isEmpty)
        #expect(!snapshot.toReview.isEmpty)
    }

    @Test func mergedSearchServerErrorKeepsSnapshot() async throws {
        let transport = FakeTransport { request in
            if variableQuery(request) == Queries.merged(since: .fixed, timeZone: .current) {
                return (Data(), httpResponse(500))
            }
            return respond(request)
        }
        let snapshot = try await client(transport).fetchSnapshot()

        #expect(!snapshot.mine.isEmpty)
        #expect(!snapshot.toReview.isEmpty)
        #expect(snapshot.mergedToday == [])
    }

    @Test func mergedSearchGraphQLErrorsWithoutDataKeepSnapshot() async throws {
        let transport = FakeTransport { request in
            if variableQuery(request) == Queries.merged(since: .fixed, timeZone: .current) {
                return (Data(#"{"errors":[{"message":"boom"}]}"#.utf8), httpResponse(200))
            }
            return respond(request)
        }
        let snapshot = try await client(transport).fetchSnapshot()

        #expect(!snapshot.mine.isEmpty)
        #expect(!snapshot.toReview.isEmpty)
        #expect(snapshot.mergedToday == [])
    }

    @Test func mergedSearchMalformedPayloadKeepsSnapshot() async throws {
        let transport = FakeTransport { request in
            if variableQuery(request) == Queries.merged(since: .fixed, timeZone: .current) {
                return (Data(#"{"data":{"search":"x"}}"#.utf8), httpResponse(200))
            }
            return respond(request)
        }
        let snapshot = try await client(transport).fetchSnapshot()

        #expect(!snapshot.mine.isEmpty)
        #expect(snapshot.mergedToday == [])
    }

    @Test func maps401ToUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: GitHubError.unauthorized) { try await client(transport).fetchSnapshot() }
    }

    @Test func maps403WithZeroRemainingToRateLimited() async {
        let transport = FakeTransport { _ in
            (Data(), httpResponse(403, headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1793900000"]))
        }
        await #expect(throws: GitHubError.rateLimited(resetAt: Date(timeIntervalSince1970: 1_793_900_000))) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func maps500ToServer() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(502)) }
        await #expect(throws: GitHubError.server(status: 502)) { try await client(transport).fetchSnapshot() }
    }

    @Test func mapsURLErrorToNetwork() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: GitHubError.network) { try await client(transport).fetchSnapshot() }
    }

    @Test func surfacesGraphQLErrors() async {
        let transport = FakeTransport { _ in
            (Data(#"{"errors":[{"message":"x"}]}"#.utf8), httpResponse(200))
        }
        await #expect(throws: GitHubError.graphQL(messages: ["x"])) { try await client(transport).fetchSnapshot() }
    }

    @Test func nullNodesFromSSOProtectedOrgAreSkipped() async throws {
        let transport = FakeTransport { respond($0, mine: "search-mine-sso") }
        let snapshot = try await client(transport).fetchSnapshot()
        #expect(snapshot.viewer == "adriano")
        #expect(snapshot.mine.map(\.id) == ["PR_101", "PR_103", "PR_104"])
        #expect(snapshot.toReview.count == 2)
    }

    @Test func malformedResponseIsUnexpectedNotNetwork() async {
        let transport = FakeTransport { _ in
            (Data(#"{"data":{"search":{"nodes":[]}}}"#.utf8), httpResponse(200))
        }
        await #expect(throws: GitHubError.unexpectedResponse) { try await client(transport).fetchSnapshot() }
    }

    @Test func maps403WithRetryAfterToRateLimited() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(403, headers: ["retry-after": "60"])) }
        await #expect(throws: GitHubError.rateLimited(resetAt: Date.fixed.addingTimeInterval(60))) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func plain403StaysServerError() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(403)) }
        await #expect(throws: GitHubError.server(status: 403)) { try await client(transport).fetchSnapshot() }
    }

    @Test func partialDataWithErrorsStillMaps() async throws {
        let transport = FakeTransport { request in
            var object = try JSONSerialization.jsonObject(with: respond(request).0) as! [String: Any]
            object["errors"] = [["message": "Resource protected by organization SAML enforcement"]]
            return (try JSONSerialization.data(withJSONObject: object), httpResponse(200))
        }
        let snapshot = try await client(transport).fetchSnapshot()
        #expect(snapshot.viewer == "adriano")
        #expect(!snapshot.mine.isEmpty)
    }

    @Test func pullRequestStatesRequestShapeAndMapping() async throws {
        let body = #"{"data":{"nodes":[{"id":"A","state":"MERGED"},null,{"id":"B","state":"OPEN"},{"id":"C","state":"WEIRD"},{}]}}"#
        let transport = FakeTransport { _ in (Data(body.utf8), httpResponse(200)) }
        let states = try await client(transport).pullRequestStates(ids: ["A", "B", "C", "D"])
        #expect(states == ["A": .merged, "B": .open])
        #expect(transport.requests.count == 1)
        let sent = try JSONSerialization.jsonObject(with: transport.requests[0].httpBody ?? Data()) as? [String: Any]
        #expect(sent?["query"] as? String == Queries.states)
        #expect((sent?["variables"] as? [String: Any])?["ids"] as? [String] == ["A", "B", "C", "D"])
        #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == "bearer t0k")
    }

    @Test func pullRequestStatesEmptyIDsSendsNothing() async throws {
        let transport = FakeTransport { _ in (Data(), httpResponse(200)) }
        #expect(try await client(transport).pullRequestStates(ids: []).isEmpty)
        #expect(transport.requests.isEmpty)
    }

    @Test func rerunPostsToRESTEndpoint() async throws {
        let transport = FakeTransport { _ in (Data(), httpResponse(201)) }
        try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        #expect(transport.requests.count == 1)
        let request = transport.requests[0]
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.github.com/repos/acme/loja/actions/runs/555/rerun-failed-jobs")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "bearer t0k")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
    }

    @Test func rerunMaps403ToServer() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(403)) }
        await #expect(throws: GitHubError.server(status: 403)) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func rerunMaps404ToServer() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(404)) }
        await #expect(throws: GitHubError.server(status: 404)) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func rerunMaps401ToUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: GitHubError.unauthorized) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func rerunMapsTransportErrorToNetwork() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: GitHubError.network) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func pullRequestStatesMaps401ToUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: GitHubError.unauthorized) { try await client(transport).pullRequestStates(ids: ["A"]) }
    }
}
