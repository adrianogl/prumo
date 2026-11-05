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
