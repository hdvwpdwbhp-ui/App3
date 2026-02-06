import SwiftUI
import UserNotifications

// HINWEIS: Wenn du bereits eine andere Datei mit @main hast,
// verwende DIESE Version ohne @main und lösche die andere.

// Wenn dies deine EINZIGE App-Datei ist, entferne die Kommentare von @main unten:

// @main
struct OperationsbegleiterApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
