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

private func client(_ transport: FakeTransport) -> GitHubClient {
    GitHubClient(token: "t0k", transport: transport, now: { Date.fixed })
}

@Suite struct GitHubClientTests {
    @Test func sendsBearerTokenAndBothSearches() async throws {
        let transport = FakeTransport { request in
            let isMine = variableQuery(request) == Queries.mine
            return (fixture(isMine ? "search-mine" : "search-review"), httpResponse(200))
        }
        let snapshot = try await client(transport).fetchSnapshot()

        #expect(transport.requests.count == 2)
        for request in transport.requests {
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.github.com/graphql")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "bearer t0k")
        }
        let queries = Set(transport.requests.compactMap(variableQuery))
        #expect(queries == [Queries.mine, Queries.review])
        #expect(snapshot.viewer == "adriano")
        #expect(snapshot.fetchedAt == Date.fixed)
        #expect(!snapshot.mine.isEmpty)
        #expect(!snapshot.toReview.isEmpty)
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
        let transport = FakeTransport { request in
            let isMine = variableQuery(request) == Queries.mine
            return (fixture(isMine ? "search-mine-sso" : "search-review"), httpResponse(200))
        }
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
            let isMine = variableQuery(request) == Queries.mine
            var object = try JSONSerialization.jsonObject(with: fixture(isMine ? "search-mine" : "search-review")) as! [String: Any]
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

    @Test func pullRequestStatesMaps401ToUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: GitHubError.unauthorized) { try await client(transport).pullRequestStates(ids: ["A"]) }
    }
}
