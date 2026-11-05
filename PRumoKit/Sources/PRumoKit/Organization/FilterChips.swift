public enum FilterChips {
    public static func chips(_ f: RowFilter, staleHours: Int) -> [FilterChip] {
        var result: [FilterChip] = []
        for value in CIFilter.allCases where f.ci.contains(value) {
            result.append(FilterChip(key: .ci(value), label: label(value)))
        }
        for value in ReviewFilter.allCases where f.review.contains(value) {
            result.append(FilterChip(key: .review(value), label: label(value)))
        }
        for value in StateFilter.allCases where f.state.contains(value) {
            result.append(FilterChip(key: .state(value), label: label(value)))
        }
        for value in RequestFilter.allCases where f.request.contains(value) {
            result.append(FilterChip(key: .request(value), label: label(value, staleHours: staleHours)))
        }
        for login in f.authors.sorted() {
            result.append(FilterChip(key: .author(login), label: OrganizationText.author(login)))
        }
        return result
    }

    private static func label(_ value: CIFilter) -> String {
        switch value {
        case .passed: OrganizationText.ciPassed
        case .running: OrganizationText.ciRunning
        case .failing: OrganizationText.ciFailing
        }
    }

    private static func label(_ value: ReviewFilter) -> String {
        switch value {
        case .approved: OrganizationText.approved
        case .changesRequested: OrganizationText.changesRequested
        case .noReview: OrganizationText.noReview
        }
    }

    private static func label(_ value: StateFilter) -> String {
        switch value {
        case .noDrafts: OrganizationText.noDrafts
        case .conflicting: OrganizationText.conflicting
        case .newActivity: OrganizationText.newActivity
        case .pinned: OrganizationText.pinned
        }
    }

    private static func label(_ value: RequestFilter, staleHours: Int) -> String {
        switch value {
        case .forYou: OrganizationText.forYou
        case .forTeam: OrganizationText.forTeam
        case .stale: OrganizationText.stale(hours: staleHours)
        }
    }
}
