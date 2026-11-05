import Foundation
import Testing
@testable import PRumoKit

private let host = "gitlab.empresa.com"

private func gitLabResponse(_ status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://\(host)/api/graphql")!, statusCode: status, httpVersion: nil, headerFields: headers)!
}

private func json(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

private func graphQLQuery(_ request: URLRequest) -> String {
    let object = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
    return object?["query"] as? String ?? ""
}

private func missingField(_ field: String, type: String) -> Data {
    json(["errors": [["message": "Field '\(field)' doesn't exist on type '\(type)'"]]])
}

private func client(_ transport: FakeTransport) -> GitLabClient {
    GitLabClient(host: host, token: "glpat-t0k", transport: transport, now: { Date.fixed })
}

@Suite struct GitLabClientTests {
    @Test func fetchSnapshotPostsQueryWithBearer() async throws {
        let transport = FakeTransport { _ in (fixture("gitlab-snapshot"), gitLabResponse(200)) }
        let snapshot = try await client(transport).fetchSnapshot()

        #expect(transport.requests.count == 1)
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://gitlab.empresa.com/api/graphql")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer glpat-t0k")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        let variables = try #require(body["variables"] as? [String: String])
        #expect(variables["mergedAfter"] == GitLabQueries.mergedAfter(since: .fixed, timeZone: .current))
        #expect(graphQLQuery(request).contains("detailedMergeStatus"))
        #expect(graphQLQuery(request).contains("mergeRequestInteraction"))
        #expect(snapshot.viewer == "adriano")
        #expect(snapshot.mine.count == 6)
    }

    @Test func mergedAfterIsLocalMidnight() {
        let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
        #expect(GitLabQueries.mergedAfter(since: .fixed, timeZone: saoPaulo) == "2026-11-05T00:00:00-03:00")
    }

    @Test func queryOmitsMissingCapabilities() {
        let minimal = GitLabQueries.snapshot(.minimal)
        #expect(!minimal.contains("detailedMergeStatus"))
        #expect(!minimal.contains("mergeRequestInteraction"))
        #expect(minimal.contains("reviewers { nodes { username } }"))

        let full = GitLabQueries.snapshot(GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: true))
        #expect(full.contains("detailedMergeStatus"))
        #expect(full.contains("mergeRequestInteraction { reviewState }"))

        let onlyState = GitLabQueries.snapshot(GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: false))
        #expect(!onlyState.contains("detailedMergeStatus"))
        #expect(onlyState.contains("mergeRequestInteraction"))
    }

    @Test func capabilitiesStartFull() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(500)) }
        let capabilities = await client(transport).capabilities()
        #expect(capabilities == GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: true))
        #expect(transport.requests.isEmpty)
    }

    @Test func missingFieldErrorDropsCapabilityAndRetries() async throws {
        let transport = FakeTransport { request in
            let query = graphQLQuery(request)
            if query.contains("detailedMergeStatus") {
                return (missingField("detailedMergeStatus", type: "MergeRequest"), gitLabResponse(200))
            }
            return (fixture("gitlab-snapshot-old"), gitLabResponse(200))
        }
        let gitlab = client(transport)
        let snapshot = try await gitlab.fetchSnapshot()

        #expect(transport.requests.count == 2)
        let retried = graphQLQuery(transport.requests[1])
        #expect(!retried.contains("detailedMergeStatus"))
        #expect(retried.contains("mergeRequestInteraction"))
        #expect(await gitlab.capabilities() == GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: false))
        #expect(snapshot.mine.first?.mergeReady == nil)
    }

    @Test func reviewStateFieldErrorDropsReviewState() async throws {
        let transport = FakeTransport { request in
            if graphQLQuery(request).contains("reviewState") {
                return (missingField("reviewState", type: "UserMergeRequestInteraction"), gitLabResponse(200))
            }
            return (fixture("gitlab-snapshot-old"), gitLabResponse(200))
        }
        let gitlab = client(transport)
        _ = try await gitlab.fetchSnapshot()

        #expect(transport.requests.count == 2)
        #expect(!graphQLQuery(transport.requests[1]).contains("reviewState"))
        #expect(await gitlab.capabilities() == GitLabCapabilities(hasReviewState: false, hasDetailedMergeStatus: true))
    }

    @Test func bothMissingFieldsDroppedInOneRetry() async throws {
        let transport = FakeTransport { request in
            let query = graphQLQuery(request)
            if query.contains("detailedMergeStatus") || query.contains("mergeRequestInteraction") {
                return (json(["errors": [
                    ["message": "Field 'detailedMergeStatus' doesn't exist on type 'MergeRequest'"],
                    ["message": "Field 'mergeRequestInteraction' doesn't exist on type 'MergeRequestReviewer'"],
                ]]), gitLabResponse(200))
            }
            return (fixture("gitlab-snapshot-old"), gitLabResponse(200))
        }
        let gitlab = client(transport)
        _ = try await gitlab.fetchSnapshot()

        #expect(transport.requests.count == 2)
        #expect(await gitlab.capabilities() == .minimal)
    }

    @Test func capabilitiesCachedAfterFirstFallback() async throws {
        let transport = FakeTransport { request in
            if graphQLQuery(request).contains("mergeRequestInteraction") {
                return (missingField("mergeRequestInteraction", type: "MergeRequestReviewer"), gitLabResponse(200))
            }
            return (fixture("gitlab-snapshot-old"), gitLabResponse(200))
        }
        let gitlab = client(transport)
        _ = try await gitlab.fetchSnapshot()
        #expect(transport.requests.count == 2)

        _ = try await gitlab.fetchSnapshot()
        #expect(transport.requests.count == 3)
        #expect(!graphQLQuery(transport.requests[2]).contains("mergeRequestInteraction"))
    }

    @Test func replacingTokenKeepsCapabilities() async throws {
        let transport = FakeTransport { request in
            graphQLQuery(request).contains("detailedMergeStatus")
                ? (missingField("detailedMergeStatus", type: "MergeRequest"), gitLabResponse(200))
                : (fixture("gitlab-snapshot"), gitLabResponse(200))
        }
        let original = client(transport)
        _ = try await original.fetchSnapshot()
        let renewed = original.replacingToken("glpat-n0vo")

        #expect(await renewed.capabilities().hasDetailedMergeStatus == false)
        _ = try await renewed.fetchSnapshot()
        let last = try #require(transport.requests.last)
        #expect(last.value(forHTTPHeaderField: "Authorization") == "Bearer glpat-n0vo")
        #expect(!graphQLQuery(last).contains("detailedMergeStatus"))
        #expect(transport.requests.count == 3)
    }

    @Test func otherGraphQLErrorIsNotRetried() async {
        let transport = FakeTransport { _ in
            (json(["errors": [["message": "Internal server error"]]]), gitLabResponse(200))
        }
        await #expect(throws: ProviderError.graphQL(messages: ["Internal server error"])) {
            try await client(transport).fetchSnapshot()
        }
        #expect(transport.requests.count == 1)
    }

    @Test func secondMissingFieldErrorIsThrown() async {
        let transport = FakeTransport { _ in
            (missingField("diffStatsSummary", type: "MergeRequest"), gitLabResponse(200))
        }
        await #expect(throws: ProviderError.graphQL(messages: ["Field 'diffStatsSummary' doesn't exist on type 'MergeRequest'"])) {
            try await client(transport).fetchSnapshot()
        }
        #expect(transport.requests.count == 1)
    }

    @Test func unauthorized401() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(401)) }
        await #expect(throws: ProviderError.unauthorized) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func rateLimited429UsesRetryAfter() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(429, headers: ["Retry-After": "60"])) }
        await #expect(throws: ProviderError.rateLimited(resetAt: Date.fixed.addingTimeInterval(60))) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func rateLimited429UsesRateLimitReset() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(429, headers: ["RateLimit-Reset": "1793900000"])) }
        await #expect(throws: ProviderError.rateLimited(resetAt: Date(timeIntervalSince1970: 1_793_900_000))) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func otherStatusIsServerError() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(503)) }
        await #expect(throws: ProviderError.server(status: 503)) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func graphQLErrorsWithoutData() async {
        let transport = FakeTransport { _ in
            (json(["errors": [["message": "boom"]], "data": NSNull()]), gitLabResponse(200))
        }
        await #expect(throws: ProviderError.graphQL(messages: ["boom"])) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func unexpectedJSONIsUnexpectedResponse() async {
        let transport = FakeTransport { _ in (json(["data": ["currentUser": ["username": "adriano"]]]), gitLabResponse(200)) }
        await #expect(throws: ProviderError.unexpectedResponse) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func transportErrorIsNetwork() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: ProviderError.network) {
            try await client(transport).fetchSnapshot()
        }
    }

    @Test func currentUsernameReadsCurrentUser() async throws {
        let transport = FakeTransport { _ in
            (json(["data": ["currentUser": ["username": "adriano"]]]), gitLabResponse(200))
        }
        #expect(try await client(transport).currentUsername() == "adriano")
        #expect(graphQLQuery(try #require(transport.requests.first)) == GitLabQueries.currentUser)
    }

    @Test func currentUsernameNullIsUnauthorized() async {
        let transport = FakeTransport { _ in (json(["data": ["currentUser": NSNull()]]), gitLabResponse(200)) }
        await #expect(throws: ProviderError.unauthorized) {
            try await client(transport).currentUsername()
        }
    }

    @Test func statesFromRESTSkipOtherHosts() async throws {
        let transport = FakeTransport { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/projects/77/merge_requests/12") { return (json(["state": "opened"]), gitLabResponse(200)) }
            if path.hasSuffix("/projects/77/merge_requests/13") { return (json(["state": "merged"]), gitLabResponse(200)) }
            if path.hasSuffix("/projects/78/merge_requests/40") { return (json(["state": "closed"]), gitLabResponse(200)) }
            return (Data(), gitLabResponse(500))
        }
        let states = try await client(transport).pullRequestStates(ids: [
            "gitlab:gitlab.empresa.com:77:12",
            "gitlab:gitlab.empresa.com:77:13",
            "gitlab:gitlab.empresa.com:78:40",
            "gitlab:gitlab.empresa.com:78:41",
            "gitlab:gitlab.com:77:12",
            "PR_812",
        ])

        #expect(states == [
            "gitlab:gitlab.empresa.com:77:12": .open,
            "gitlab:gitlab.empresa.com:77:13": .merged,
            "gitlab:gitlab.empresa.com:78:40": .closed,
        ])
        #expect(transport.requests.count == 4)
        for request in transport.requests {
            #expect(request.httpMethod == "GET")
            #expect(request.url?.host == "gitlab.empresa.com")
            #expect(request.url?.path.hasPrefix("/api/v4/projects/") == true)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer glpat-t0k")
        }
    }

    @Test func statesLimitedToTwentyIDs() async throws {
        let transport = FakeTransport { _ in (json(["state": "opened"]), gitLabResponse(200)) }
        let ids = (1...25).map { GitLabID.make(host: host, projectID: 77, iid: $0) }
        let states = try await client(transport).pullRequestStates(ids: ids)
        #expect(states.count == 20)
        #expect(transport.requests.count == 20)
    }

    @Test func tokenScopesFromPersonalAccessToken() async {
        let transport = FakeTransport { _ in (json(["scopes": ["read_api", "read_user"]]), gitLabResponse(200)) }
        #expect(await client(transport).tokenScopes() == ["read_api", "read_user"])
        #expect(transport.requests.first?.url?.absoluteString == "https://gitlab.empresa.com/api/v4/personal_access_tokens/self")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer glpat-t0k")
    }

    @Test func tokenScopesFallsBackToOAuthInfo() async {
        let transport = FakeTransport { request in
            if request.url?.path == "/oauth/token/info" {
                return (json(["scope": ["api"], "expires_in": 7000]), gitLabResponse(200))
            }
            return (json(["message": "400 Bad request - requires token type to be a personal access token"]), gitLabResponse(400))
        }
        #expect(await client(transport).tokenScopes() == ["api"])
        #expect(transport.requests.map { $0.url?.path } == ["/api/v4/personal_access_tokens/self", "/oauth/token/info"])
    }

    @Test func tokenScopesNilOnError() async {
        let failing = FakeTransport { _ in (Data(), gitLabResponse(500)) }
        #expect(await client(failing).tokenScopes() == nil)
        #expect(failing.requests.count == 1)

        let offline = FakeTransport { _ in throw URLError(.timedOut) }
        #expect(await client(offline).tokenScopes() == nil)

        let oauthFails = FakeTransport { _ in (Data(), gitLabResponse(400)) }
        #expect(await client(oauthFails).tokenScopes() == nil)
        #expect(oauthFails.requests.count == 2)
    }

    private func retryResponse(_ errors: [String]) -> Data {
        json(["data": ["pipelineRetry": ["errors": errors]]])
    }

    @Test func retryMutationSendsPipelineGID() async throws {
        let transport = FakeTransport { _ in (retryResponse([]), gitLabResponse(200)) }
        try await client(transport).rerunFailedJobs(pr: .fixture(failedRunID: 987))
        let query = graphQLQuery(transport.requests[0])
        #expect(query.contains("pipelineRetry"))
        #expect(query.contains("gid://gitlab/Ci::Pipeline/987"))
    }

    @Test func retry403MapsToServer403() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(403)) }
        await #expect(throws: ProviderError.server(status: 403)) {
            try await client(transport).rerunFailedJobs(pr: .fixture(failedRunID: 987))
        }
    }

    @Test func retryErrorsMapToGraphQL() async {
        let transport = FakeTransport { _ in (retryResponse(["Pipeline not retryable"]), gitLabResponse(200)) }
        await #expect(throws: ProviderError.graphQL(messages: ["Pipeline not retryable"])) {
            try await client(transport).rerunFailedJobs(pr: .fixture(failedRunID: 987))
        }
    }

    @Test func retryWithoutRunIDIsUnexpected() async {
        let transport = FakeTransport { _ in (retryResponse([]), gitLabResponse(200)) }
        await #expect(throws: ProviderError.unexpectedResponse) {
            try await client(transport).rerunFailedJobs(pr: .fixture(failedRunID: nil))
        }
        #expect(transport.requests.isEmpty)
    }

    @Test func gitlabCancelThenRetry() async throws {
        let transport = FakeTransport { request in
            let field = graphQLQuery(request).contains("pipelineCancel") ? "pipelineCancel" : "pipelineRetry"
            return (json(["data": [field: ["errors": [String]()]]]), gitLabResponse(200))
        }
        try await client(transport).cancelAndRerun(pr: .fixture(provider: .gitlab, pendingRunIDs: [5003]))
        let queries = transport.requests.map(graphQLQuery)
        #expect(queries.count == 2)
        #expect(queries[0].contains("pipelineCancel(input: {id: \"gid://gitlab/Ci::Pipeline/5003\"})"))
        #expect(queries[1].contains("pipelineRetry(input: {id: \"gid://gitlab/Ci::Pipeline/5003\"})"))
    }

    @Test func gitlabCancelErrorsStopBeforeRetry() async {
        let transport = FakeTransport { _ in
            (json(["data": ["pipelineCancel": ["errors": ["Pipeline não pode ser cancelado"]]]]), gitLabResponse(200))
        }
        await #expect(throws: ProviderError.graphQL(messages: ["Pipeline não pode ser cancelado"])) {
            try await client(transport).cancelAndRerun(pr: .fixture(provider: .gitlab, pendingRunIDs: [5003]))
        }
        #expect(transport.requests.count == 1)
    }

    @Test func gitlabCancelWithoutPipelineSendsNothing() async {
        let transport = FakeTransport { _ in (Data(), gitLabResponse(200)) }
        await #expect(throws: ProviderError.unexpectedResponse) {
            try await client(transport).cancelAndRerun(pr: .fixture(provider: .gitlab))
        }
        #expect(transport.requests.isEmpty)
    }
}
