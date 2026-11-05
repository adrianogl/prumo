public enum PromptTemplate {
    public static func render(_ template: String, values: [String: String]) -> String {
        var result = ""
        var index = template.startIndex
        while index < template.endIndex {
            let character = template[index]
            if character == "{",
                let close = template[index...].firstIndex(of: "}"),
                let value = values[String(template[template.index(after: index)..<close])]
            {
                result += value
                index = template.index(after: close)
            } else {
                result.append(character)
                index = template.index(after: index)
            }
        }
        return result
    }
}

public enum PromptValues {
    public static func review(_ pr: PullRequest) -> [String: String] {
        [
            "numero": String(pr.number),
            "url": pr.url.absoluteString,
            "repo": pr.repository,
            "branch": pr.headRefName,
            "titulo": pr.title,
        ]
    }

    public static func ci(_ pr: PullRequest) -> [String: String] {
        var values = review(pr)
        values["job"] = firstFailedCheck(pr.ci)
        values["run"] = pr.failedRunID.map(String.init) ?? ""
        return values
    }

    private static func firstFailedCheck(_ ci: CIStatus) -> String {
        if case .failure(let checks, _) = ci { return checks.first ?? "" }
        return ""
    }
}
