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
        await #expect(throws: ProviderError.unauthorized) { try await client(transport).fetchSnapshot() }
    }

    @Test func maps403WithZeroRemainingToRateLimited() async {
        let transport = FakeTransport { _ in
            (Data(), httpResponse(403, headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1793900000"]))
        }
        await #expect(throws: ProviderError.rateLimited(resetAt: Date(timeIntervalSince1970: 1_793_900_000))) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func maps500ToServer() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(502)) }
        await #expect(throws: ProviderError.server(status: 502)) { try await client(transport).fetchSnapshot() }
    }

    @Test func mapsURLErrorToNetwork() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: ProviderError.network) { try await client(transport).fetchSnapshot() }
    }

    @Test func surfacesGraphQLErrors() async {
        let transport = FakeTransport { _ in
            (Data(#"{"errors":[{"message":"x"}]}"#.utf8), httpResponse(200))
        }
        await #expect(throws: ProviderError.graphQL(messages: ["x"])) { try await client(transport).fetchSnapshot() }
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
        await #expect(throws: ProviderError.unexpectedResponse) { try await client(transport).fetchSnapshot() }
    }

    @Test func maps403WithRetryAfterToRateLimited() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(403, headers: ["retry-after": "60"])) }
        await #expect(throws: ProviderError.rateLimited(resetAt: Date.fixed.addingTimeInterval(60))) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func plain403StaysServerError() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(403)) }
        await #expect(throws: ProviderError.server(status: 403)) { try await client(transport).fetchSnapshot() }
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
        await #expect(throws: ProviderError.server(status: 403)) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func rerunMaps404ToServer() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(404)) }
        await #expect(throws: ProviderError.server(status: 404)) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func rerunMaps401ToUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: ProviderError.unauthorized) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func rerunMapsTransportErrorToNetwork() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: ProviderError.network) {
            try await client(transport).rerunFailedJobs(repository: "acme/loja", runID: 555)
        }
    }

    @Test func pullRequestStatesMaps401ToUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: ProviderError.unauthorized) { try await client(transport).pullRequestStates(ids: ["A"]) }
    }

    @Test func viewerLoginParsesLogin() async throws {
        let transport = FakeTransport { _ in (Data(#"{"data":{"viewer":{"login":"globex-dev"}}}"#.utf8), httpResponse(200)) }
        let login = try await client(transport).viewerLogin()
        #expect(login == "globex-dev")
        let body = try JSONSerialization.jsonObject(with: transport.requests[0].httpBody ?? Data()) as? [String: Any]
        #expect(body?["query"] as? String == Queries.viewer)
    }

    @Test func viewerLogin401IsUnauthorized() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(401)) }
        await #expect(throws: ProviderError.unauthorized) { try await client(transport).viewerLogin() }
    }

    @Test func rerunUsesFailedRunOfPR() async throws {
        let transport = FakeTransport { _ in (Data(), httpResponse(201)) }
        try await client(transport).rerunFailedJobs(pr: .fixture(repository: "acme/loja", failedRunID: 42))
        #expect(transport.requests.count == 1)
        #expect(transport.requests[0].url?.absoluteString == "https://api.github.com/repos/acme/loja/actions/runs/42/rerun-failed-jobs")
    }

    @Test func rerunWithoutRunIsUnexpected() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(201)) }
        await #expect(throws: ProviderError.unexpectedResponse) {
            try await client(transport).rerunFailedJobs(pr: .fixture(failedRunID: nil))
        }
        #expect(transport.requests.isEmpty)
    }

    private final class SleepLog: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Duration] = []
        var durations: [Duration] { lock.withLock { recorded } }
        func record(_ duration: Duration) { lock.withLock { recorded.append(duration) } }
    }

    private func runStatus(_ status: String) -> Data {
        Data(#"{"id":1,"status":"\#(status)"}"#.utf8)
    }

    private func sleepingClient(_ transport: FakeTransport, log: SleepLog) -> GitHubClient {
        GitHubClient(token: "t0k", transport: transport, now: { Date.fixed }, sleep: { log.record($0) })
    }

    @Test func githubCancelThenRerunOrder() async throws {
        let polls = SleepLog()
        let gets = NSLock()
        nonisolated(unsafe) var getCount = 0
        let transport = FakeTransport { request in
            if request.httpMethod == "GET" {
                let count = gets.withLock { getCount += 1; return getCount }
                return (runStatus(count < 3 ? "in_progress" : "completed"), httpResponse(200))
            }
            return (Data(), httpResponse(202))
        }
        let pr = PullRequest.fixture(repository: "acme/loja")
        try await sleepingClient(transport, log: polls).cancelAndRerun(pr: pr, runIDs: [4242])

        let base = "https://api.github.com/repos/acme/loja/actions/runs/4242"
        #expect(transport.requests.map { "\($0.httpMethod ?? "") \($0.url?.absoluteString ?? "")" } == [
            "POST \(base)/cancel",
            "GET \(base)",
            "GET \(base)",
            "GET \(base)",
            "POST \(base)/rerun",
        ])
        #expect(polls.durations == [.seconds(2), .seconds(2)])
        #expect(transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "bearer t0k" })
    }

    @Test func githubCancelTimeoutFails() async {
        let polls = SleepLog()
        let transport = FakeTransport { request in
            request.httpMethod == "GET" ? (runStatus("queued"), httpResponse(200)) : (Data(), httpResponse(202))
        }
        let pr = PullRequest.fixture(repository: "acme/loja")
        await #expect(throws: ProviderError.cancelTimedOut(runID: 4242)) {
            try await sleepingClient(transport, log: polls).cancelAndRerun(pr: pr, runIDs: [4242])
        }
        #expect(polls.durations.reduce(.zero, +) == .seconds(30))
        #expect(!transport.requests.contains { $0.url?.lastPathComponent == "rerun" })
    }

    @Test func githubTimeoutOnOneRunStillRerunsTheOther() async {
        let polls = SleepLog()
        let transport = FakeTransport { request in
            guard request.httpMethod == "GET" else { return (Data(), httpResponse(202)) }
            let finished = request.url?.lastPathComponent == "1"
            return (runStatus(finished ? "completed" : "queued"), httpResponse(200))
        }
        await #expect(throws: ProviderError.cancelTimedOut(runID: 2)) {
            try await sleepingClient(transport, log: polls).cancelAndRerun(repository: "acme/loja", runIDs: [1, 2])
        }
        let base = "https://api.github.com/repos/acme/loja/actions/runs"
        let posts = transport.requests.filter { $0.httpMethod == "POST" }.map { $0.url?.absoluteString ?? "" }
        #expect(posts == ["\(base)/1/cancel", "\(base)/2/cancel", "\(base)/1/rerun"])
        #expect(polls.durations.reduce(.zero, +) == .seconds(30))
    }

    @Test func githubCancelOfFinishedRunStillReruns() async throws {
        let transport = FakeTransport { request in
            if request.url?.lastPathComponent == "cancel" { return (Data(), httpResponse(409)) }
            if request.httpMethod == "GET" { return (runStatus("completed"), httpResponse(200)) }
            return (Data(), httpResponse(201))
        }
        let pr = PullRequest.fixture(repository: "acme/loja")
        try await sleepingClient(transport, log: SleepLog()).cancelAndRerun(pr: pr, runIDs: [4242])
        #expect(transport.requests.last?.url?.lastPathComponent == "rerun")
    }

    @Test func githubCancelWithoutRunsSendsNothing() async {
        let transport = FakeTransport { _ in (Data(), httpResponse(202)) }
        await #expect(throws: ProviderError.unexpectedResponse) {
            try await client(transport).cancelAndRerun(pr: .fixture(), runIDs: [])
        }
        #expect(transport.requests.isEmpty)
    }
}
