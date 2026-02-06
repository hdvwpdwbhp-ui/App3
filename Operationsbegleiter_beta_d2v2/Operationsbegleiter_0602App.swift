//
//  Operationsbegleiter_0602App.swift
//  Operationsbegleiter_0602
//
//  Created by App on 06.02.26.
//

import SwiftUI
import UserNotifications

@main
struct Operationsbegleiter_0602App: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
