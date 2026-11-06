import Foundation

public struct UpdateChecker: Sendable {
    private let installed: AppVersion
    private let transport: HTTPTransport

    public init(installed: AppVersion, transport: HTTPTransport = URLSessionTransport()) {
        self.installed = installed
        self.transport = transport
    }

    public func check() async throws(UpdateError) -> ReleaseInfo? {
        var request = URLRequest(url: UpdateConstants.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            throw .network
        }
        switch response.statusCode {
        case 200..<300:
            break
        case UpdateConstants.notFoundStatus:
            return nil
        case let status where UpdateConstants.rateLimitStatuses.contains(status):
            throw .rateLimited
        default:
            throw .server(status: response.statusCode)
        }
        guard let release = ReleaseInfo.decode(data) else { throw .unexpectedResponse }
        return release.version > installed ? release : nil
    }
}
