import SwiftUI
import UserNotifications
import PRumoKit

@main
struct PRumoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        let notifications = NotificationService()
        UNUserNotificationCenter.current().delegate = notifications
        let model = AppModel(notifications: notifications)
        _model = State(initialValue: model)
        model.start()
        model.registerHotKey()
        model.updates.start()
        let window = model.mainWindow
        AppDelegate.reopen = { window.open() }
        AppDelegate.shouldTerminate = { model.confirmQuitWithLiveSessions() }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window(MainWindowText.title, id: MainWindowText.id) {
            MainWindowView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: MainWindowMetrics.defaultWidth, height: MainWindowMetrics.defaultHeight)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

        Window(OnboardingText.windowTitle, id: OnboardingText.id) {
            OnboardingView(app: model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(model: model)
        }
    }
}
