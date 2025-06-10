import SwiftUI
import SwiftData
import WebKit
import UserNotifications
import AppKit
import ServiceManagement
import Sparkle

@main
struct LobbyOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    var window: NSWindow!
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    private var updater: SPUUpdater?
    private var driver: SPUStandardUserDriver?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ✅ Create the SwiftUI content
        let contentView = ContentView()

        // ✅ Create and configure window immediately
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Lobby"
        window.setFrameAutosaveName("MainWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        window.isReleasedWhenClosed = false

        // ✅ Ask for notification permission
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("[✅] Notification permission granted")
                } else if let error = error {
                    print("[❌] Notification error: \(error)")
                }
            }
        }
        
        // Set up auto-launch
        setupAutoLaunch()
        
        // Set up Sparkle
        setupSparkle()
        
        // Set up menu bar
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        let mainMenu = NSMenu()
        
        // App menu
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = NSMenu()
        let appMenu = appMenuItem.submenu!
        appMenu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        mainMenu.addItem(appMenuItem)
        
        NSApplication.shared.mainMenu = mainMenu
    }
    
    @objc private func checkForUpdates() {
        updater?.checkForUpdates()
    }
    
    private func setupSparkle() {
        driver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        do {
            updater = try SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: driver!, delegate: nil)
            try updater?.start()
        } catch {
            print("Failed to initialize Sparkle: \(error)")
        }
    }
    
    private func setupAutoLaunch() {
        if launchAtLogin {
            if SMAppService.mainApp.status != .enabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    print("Failed to register for auto-launch: \(error)")
                }
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    print("Failed to unregister from auto-launch: \(error)")
                }
            }
        }
    }

    // ✅ Prevent app from quitting on close
    func windowWillClose(_ notification: Notification) {
        window.orderOut(nil)
    }

    // ✅ Reopen hidden window from Dock
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
