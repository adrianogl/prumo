import SwiftUI
import PRumoKit

@main
struct PRumoApp: App {
    var body: some Scene {
        MenuBarExtra("PRumo", systemImage: "arrow.triangle.pull") {
            Text("PRumo")
        }
        .menuBarExtraStyle(.window)
    }
}
