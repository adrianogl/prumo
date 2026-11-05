import Foundation
import Testing
@testable import PRumoKit

@Suite struct GitLabAddressTests {
    @Test func addressNormalizesHttpsAndSlash() {
        #expect(GitLabAddress.normalize("https://GitLab.Empresa.com/") == .success("gitlab.empresa.com"))
        #expect(GitLabAddress.normalize("  gitlab.com//  ") == .success("gitlab.com"))
    }

    @Test func addressDefaultsToGitLabWhenEmpty() {
        #expect(GitLabAddress.normalize("   ") == .success("gitlab.com"))
    }

    @Test func addressRejectsHttp() {
        #expect(GitLabAddress.normalize("http://gitlab.empresa.com") == .failure(.insecure))
        #expect(GitLabAddress.normalize("HTTP://gitlab.empresa.com/") == .failure(.insecure))
    }

    @Test func addressAcceptsPort() {
        #expect(GitLabAddress.normalize("gitlab.local:8443") == .success("gitlab.local:8443"))
        #expect(GitLabAddress.normalize("https://gitlab.local:8443/") == .success("gitlab.local:8443"))
    }

    @Test func addressRejectsInvalid() {
        for raw in ["gitlab empresa", "gitlab.com/grupo", "ftp://gitlab.com", "-gitlab.com", "gitlab..com",
                    "gitlab.com:", "gitlab.com:0", "gitlab.com:70000", "https://", "gitlab.com?x=1", "user@gitlab.com"] {
            #expect(GitLabAddress.normalize(raw) == .failure(.invalid), "\(raw)")
        }
    }

    @Test func tokenCreationURLUsesHost() {
        #expect(GitLabAddress.tokenCreationURL(host: "gitlab.local:8443").absoluteString
            == "https://gitlab.local:8443/-/user_settings/personal_access_tokens?name=PRumo&scopes=read_api")
    }
}
