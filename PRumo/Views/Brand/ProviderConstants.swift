import PRumoKit

enum ProviderSymbol {
    static func asset(_ kind: ProviderKind) -> String {
        switch kind {
        case .github: "ProviderGitHub"
        case .gitlab: "ProviderGitLab"
        }
    }
}
