import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow!
    var appState: AppState!

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        
        NSApp.setActivationPolicy(.accessory) // Hide from Dock and App Switcher
        
        overlayWindow = OverlayWindow(appState: appState)
        overlayWindow.makeKeyAndOrderFront(nil)
        
        // Initialize HotKey Manager
        HotKeyManager.shared.setup(appState: appState, overlayWindow: overlayWindow)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

