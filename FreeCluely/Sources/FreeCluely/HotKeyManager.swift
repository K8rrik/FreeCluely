import Carbon
import AppKit
import SwiftUI

class HotKeyManager {
    static let shared = HotKeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var appState: AppState?
    private weak var overlayWindow: OverlayWindow?
    
    private var activeHotKeys: Set<UInt32> = []
    private var moveTimer: Timer?
    
    private init() {}
    
    func setup(appState: AppState, overlayWindow: OverlayWindow) {
        self.appState = appState
        self.overlayWindow = overlayWindow
        
        // Register Cmd+Shift+A (Analyze)
        // Cmd = cmdKey (55), Shift = shiftKey (56), A = 0
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("swat".asUInt32) // Unique signature
        hotKeyID.id = 1
        
        let modifierFlags: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 0 // 'A' key
        
        let status = RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            print("Error registering capture hotkey: \(status)")
        }
        
        // Register Cmd+Shift+W (Toggle Visibility/Window)
        var toggleHotKeyID = EventHotKeyID()
        toggleHotKeyID.signature = OSType("swat".asUInt32)
        toggleHotKeyID.id = 2
        
        let toggleKeyCode: UInt32 = 13 // 'W' key
        var toggleHotKeyRef: EventHotKeyRef?
        
        let toggleStatus = RegisterEventHotKey(toggleKeyCode, modifierFlags, toggleHotKeyID, GetApplicationEventTarget(), 0, &toggleHotKeyRef)
        
        if toggleStatus != noErr {
            print("Error registering toggle hotkey: \(toggleStatus)")
        }


        
        // Register Cmd+Shift+C (Clear)
        var clearHotKeyID = EventHotKeyID()
        clearHotKeyID.signature = OSType("swat".asUInt32)
        clearHotKeyID.id = 4
        
        let clearKeyCode: UInt32 = 8 // 'C' key
        var clearHotKeyRef: EventHotKeyRef?
        
        let clearStatus = RegisterEventHotKey(clearKeyCode, modifierFlags, clearHotKeyID, GetApplicationEventTarget(), 0, &clearHotKeyRef)
        
        if clearStatus != noErr {
            print("Error registering clear hotkey: \(clearStatus)")
        }
        
        // Register Cmd+Shift+H (History)
        var historyHotKeyID = EventHotKeyID()
        historyHotKeyID.signature = OSType("swat".asUInt32)
        historyHotKeyID.id = 5
        
        let historyKeyCode: UInt32 = 4 // 'H' key
        var historyHotKeyRef: EventHotKeyRef?
        
        let historyStatus = RegisterEventHotKey(historyKeyCode, modifierFlags, historyHotKeyID, GetApplicationEventTarget(), 0, &historyHotKeyRef)
        
        if historyStatus != noErr {
            print("Error registering history hotkey: \(historyStatus)")
        }
        
        // Register Cmd + Arrow keys for window movement
        let arrowModifierFlags: UInt32 = UInt32(cmdKey)
        
        // Cmd + Left Arrow
        var leftArrowHotKeyID = EventHotKeyID()
        leftArrowHotKeyID.signature = OSType("swat".asUInt32)
        leftArrowHotKeyID.id = 6
        var leftArrowHotKeyRef: EventHotKeyRef?
        let leftArrowStatus = RegisterEventHotKey(123, arrowModifierFlags, leftArrowHotKeyID, GetApplicationEventTarget(), 0, &leftArrowHotKeyRef)
        if leftArrowStatus != noErr {
            print("Error registering left arrow hotkey: \(leftArrowStatus)")
        }
        
        // Cmd + Right Arrow
        var rightArrowHotKeyID = EventHotKeyID()
        rightArrowHotKeyID.signature = OSType("swat".asUInt32)
        rightArrowHotKeyID.id = 7
        var rightArrowHotKeyRef: EventHotKeyRef?
        let rightArrowStatus = RegisterEventHotKey(124, arrowModifierFlags, rightArrowHotKeyID, GetApplicationEventTarget(), 0, &rightArrowHotKeyRef)
        if rightArrowStatus != noErr {
            print("Error registering right arrow hotkey: \(rightArrowStatus)")
        }
        
        // Cmd + Down Arrow
        var downArrowHotKeyID = EventHotKeyID()
        downArrowHotKeyID.signature = OSType("swat".asUInt32)
        downArrowHotKeyID.id = 8
        var downArrowHotKeyRef: EventHotKeyRef?
        let downArrowStatus = RegisterEventHotKey(125, arrowModifierFlags, downArrowHotKeyID, GetApplicationEventTarget(), 0, &downArrowHotKeyRef)
        if downArrowStatus != noErr {
            print("Error registering down arrow hotkey: \(downArrowStatus)")
        }
        
        // Cmd + Up Arrow
        var upArrowHotKeyID = EventHotKeyID()
        upArrowHotKeyID.signature = OSType("swat".asUInt32)
        upArrowHotKeyID.id = 9
        var upArrowHotKeyRef: EventHotKeyRef?
        let upArrowStatus = RegisterEventHotKey(126, arrowModifierFlags, upArrowHotKeyID, GetApplicationEventTarget(), 0, &upArrowHotKeyRef)
        if upArrowStatus != noErr {
            print("Error registering up arrow hotkey: \(upArrowStatus)")
        }
        
        // Install event handler
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if status == noErr {
                let kind = GetEventKind(event)
                
                if kind == UInt32(kEventHotKeyPressed) {
                    if [6, 7, 8, 9].contains(hotKeyID.id) {
                        DispatchQueue.main.async {
                            HotKeyManager.shared.activeHotKeys.insert(hotKeyID.id)
                            HotKeyManager.shared.processMovement()
                            HotKeyManager.shared.startMoveTimer()
                        }
                    } else {
                        if hotKeyID.id == 1 {
                            HotKeyManager.shared.handleCaptureHotKey()
                        } else if hotKeyID.id == 2 {
                            HotKeyManager.shared.handleToggleHotKey()
                        } else if hotKeyID.id == 4 {
                            HotKeyManager.shared.handleClearHotKey()
                        } else if hotKeyID.id == 5 {
                            HotKeyManager.shared.handleHistoryHotKey()
                        }
                    }
                } else if kind == UInt32(kEventHotKeyReleased) {
                    if [6, 7, 8, 9].contains(hotKeyID.id) {
                        DispatchQueue.main.async {
                            HotKeyManager.shared.activeHotKeys.remove(hotKeyID.id)
                            if HotKeyManager.shared.activeHotKeys.isEmpty {
                                HotKeyManager.shared.stopMoveTimer()
                            }
                        }
                    }
                }
            }
            return noErr
        }, 2, &eventTypes, nil, nil)
    }
    
    func startMoveTimer() {
        if moveTimer == nil {
            moveTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
                self?.processMovement()
            }
        }
    }
    
    func stopMoveTimer() {
        moveTimer?.invalidate()
        moveTimer = nil
    }
    
    func processMovement() {
        guard let window = overlayWindow else { return }
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        let speed: CGFloat = 15 // pixels per frame
        
        if activeHotKeys.contains(6) { dx -= speed }
        if activeHotKeys.contains(7) { dx += speed }
        if activeHotKeys.contains(8) { dy -= speed }
        if activeHotKeys.contains(9) { dy += speed }
        
        if dx != 0 || dy != 0 {
            window.moveWindow(dx: dx, dy: dy, animate: false)
        }
    }
    
    func handleCaptureHotKey() {
        print("Capture Hotkey pressed!")
        guard let appState = appState else { return }
        
        DispatchQueue.main.async {
            // If hidden, show it first
            if !appState.isVisible {
                appState.isVisible = true
            }
            // Close history if open
            appState.showHistory = false
            
            // Trigger capture and API call
            Task {
                await ScreenCapture.shared.captureAndAnalyze(appState: appState)
            }
        }
    }
    
    func handleToggleHotKey() {
        print("Toggle Hotkey pressed!")
        guard let appState = appState else { return }
        
        DispatchQueue.main.async {
            appState.isVisible.toggle()
        }
    }
    

    
    func handleClearHotKey() {
        print("Clear Hotkey pressed!")
        guard let appState = appState else { return }
        
        DispatchQueue.main.async {
            appState.startNewSession()
        }
    }
    
    func handleHistoryHotKey() {
        print("History Hotkey pressed!")
        guard let appState = appState else { return }
        
        DispatchQueue.main.async {
            withAnimation {
                appState.showHistory.toggle()
            }
        }
    }
    

}

extension String {
    var asUInt32: UInt32 {
        var result: UInt32 = 0
        for code in self.utf8 {
            result = (result << 8) + UInt32(code)
        }
        return result
    }
}
