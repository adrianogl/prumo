public enum FilterChipKey: Hashable, Sendable {
    case ci(CIFilter)
    case review(ReviewFilter)
    case state(StateFilter)
    case request(RequestFilter)
    case author(String)
}
