import Foundation

enum SidebarScope: Hashable {
    case all
    case view(UUID)
    case repository(String)
}
