import PRumoKit

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(ReleaseInfo)
    case failed
}
