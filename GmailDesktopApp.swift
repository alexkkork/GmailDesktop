import SwiftUI
import UserNotifications

@main
struct GmailDesktopApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
    }

    init() {
        NotificationManager.shared.requestAuthorization()
    }
}
