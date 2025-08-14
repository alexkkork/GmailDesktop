import SwiftUI
import AppKit
import UserNotifications

@main
struct GmailDesktopApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Full Screen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut(.init("f"), modifiers: [.control, .command])
            }
        }
    }

    init() {
        NotificationManager.shared.requestAuthorization()
        // Ensure the app is key and can present system sheets (e.g., passkey dialogs)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
