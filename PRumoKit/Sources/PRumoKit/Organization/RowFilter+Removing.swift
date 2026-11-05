extension RowFilter {
    public func removing(_ key: FilterChipKey) -> RowFilter {
        var copy = self
        switch key {
        case .ci(let value): copy.ci.remove(value)
        case .review(let value): copy.review.remove(value)
        case .state(let value): copy.state.remove(value)
        case .request(let value): copy.request.remove(value)
        case .author(let login): copy.authors.remove(login)
        }
        return copy
    }
}
