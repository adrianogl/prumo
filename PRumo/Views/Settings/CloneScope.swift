enum CloneScope: CaseIterable, Identifiable {
    case relevant
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .relevant: ClonesManagerText.relevant
        case .all: ClonesManagerText.all
        }
    }
}
