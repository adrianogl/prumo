import PRumoKit

struct RowActions {
    let entries: [RowMenuEntry]
    let perform: (RowMenuEntry) -> Void
}
