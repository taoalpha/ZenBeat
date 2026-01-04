//
//  ZenBeatApp.swift
//  ZenBeat
//
//  Created by Tao Zhou on 03.01.2026.
//

import SwiftUI
import SwiftData
import Combine

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let addNewReminder = Notification.Name("addNewReminder")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If the user clicks the dock icon and no windows are visible (or even if they are),
        // we want to open the Settings window since that's our main "App" interface.
        NotificationCenter.default.post(name: .openSettings, object: nil)
        return true
    }
}

@main
struct ZenBeatApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Reminder.self,
            ReminderEntry.self,
            Profile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = ReminderManager()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .modelContainer(sharedModelContainer)
                .environmentObject(manager)
        } label: {
            MenuBarLabelView()
                .modelContainer(sharedModelContainer)
                .environmentObject(manager)
        }
        .menuBarExtraStyle(.window)
        
        Window("Settings", id: "settings") {
             SettingsWindowView()
                .modelContainer(sharedModelContainer)
                .environmentObject(manager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 400)
        
        Window("Time's Up!", id: "timeup-overlay") {
            ReminderOverlayView()
                .modelContainer(sharedModelContainer)
                .environmentObject(manager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .onChange(of: manager.showTimeUpOverlay) { _, newValue in
            if newValue {
                openFullScreenOverlay(windowId: "timeup-overlay")
            } else {
                // Close the overlay window
                if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "timeup-overlay" }) {
                    window.close()
                }
            }
        }
        
        // TodayOverlay removed per user request
    .commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                openWindow(id: "settings")
            }
        }
    }
    }
    
    private func openFullScreenOverlay(windowId: String) {
        openWindow(id: windowId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == windowId }) {
                if let screen = NSScreen.main {
                    window.setFrame(screen.frame, display: true)
                }
                window.level = .screenSaver
                window.makeKeyAndOrderFront(nil)
                
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.isOpaque = false
                window.backgroundColor = .clear
                
                window.isMovable = false
                window.styleMask.remove(.resizable)
            }
        }
    }
}
