import PRumoKit

struct RowActions {
    let claudePurposes: [SessionPurpose]
    let launch: (SessionPurpose) -> Void
}
