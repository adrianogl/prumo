import SwiftUI
import PRumoKit

@main
struct PRumoApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("PRumo")
        } label: {
            Image("MenuBarGlyph")
        }
        .menuBarExtraStyle(.window)
    }
}
