import SwiftUI
import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow!
    var appState: AppState!

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for Accessibility permissions (required for global hotkey monitoring)
        checkAccessibilityPermissions()
        
        appState = AppState()
        
        NSApp.setActivationPolicy(.accessory) // Hide from Dock and App Switcher
        
        overlayWindow = OverlayWindow(appState: appState)
        appState.mainWindow = overlayWindow
        overlayWindow.makeKeyAndOrderFront(nil)
        
        // Initialize HotKey Manager
        HotKeyManager.shared.setup(appState: appState, overlayWindow: overlayWindow)
    }
    
    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessibilityEnabled {
            print("⚠️ Accessibility permissions not granted. Global hotkey (Cmd+/) will not work.")
            print("Please enable accessibility permissions in System Preferences > Privacy & Security > Accessibility")
        } else {
            print("✅ Accessibility permissions granted. Global hotkey enabled.")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

