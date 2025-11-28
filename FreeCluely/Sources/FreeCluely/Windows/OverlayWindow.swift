import AppKit
import SwiftUI
import Combine

class OverlayWindow: NSWindow {
    private var cancellables = Set<AnyCancellable>()
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?
    
    init(appState: AppState) {
        // Create a window with a reasonable default size, positioned at the bottom
        let screenRect = NSScreen.main?.frame ?? .zero
        let width: CGFloat = 600
        let height: CGFloat = 100
        let x = (screenRect.width - width) / 2
        let y = screenRect.maxY - height - 0
        
        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .fullSizeContentView], // Borderless for custom look
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar // Allow window to be above menu bar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isMovableByWindowBackground = false // Disable system dragging to prevent snapping
        self.hidesOnDeactivate = false
        
        // Don't steal focus from other apps
        self.canHide = false
        
        // Initial sharing type
        self.sharingType = .none
        
        // Bind sharingType to AppState
        appState.$isInspectable
            .sink { [weak self] isInspectable in
                self?.sharingType = isInspectable ? .readOnly : .none
            }
            .store(in: &cancellables)
        
        appState.$isVisible
            .sink { [weak self] isVisible in
                if isVisible {
                    // Show window without activating the app
                    self?.orderFrontRegardless()
                } else {
                    self?.orderOut(nil)
                }
            }
            .store(in: &cancellables)
        
        // Observe messages and loading state to resize window
        appState.$currentSession
            .map { $0.messages.count }
            .combineLatest(appState.$isLoading)
            .sink { [weak self] count, isLoading in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if count > 0 || isLoading {
                        // If we have messages or are loading, ensure we are at least 320 height
                        // But only if we are currently small (around 140)
                        if self.frame.height < 300 {
                            let currentTop = self.frame.maxY
                            let newHeight: CGFloat = 320
                            let newY = currentTop - newHeight
                            let newFrame = NSRect(x: self.frame.origin.x, y: newY, width: self.frame.width, height: newHeight)
                            self.setFrame(newFrame, display: true, animate: true)
                        }
                    } else {
                        // If empty and not loading, shrink back to 100
                        if self.frame.height > 101 {
                            let currentTop = self.frame.maxY
                            let newHeight: CGFloat = 100
                            let newY = currentTop - newHeight
                            let newFrame = NSRect(x: self.frame.origin.x, y: newY, width: self.frame.width, height: newHeight)
                            self.setFrame(newFrame, display: true, animate: true)
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // When shouldFocusInput is triggered, activate app and make window key
        appState.$shouldFocusInput
            .sink { [weak self] shouldFocus in
                if shouldFocus {
                    NSApp.activate(ignoringOtherApps: true)
                    self?.makeKeyAndOrderFront(nil)
                }
            }
            .store(in: &cancellables)
        
        let overlayView = OverlayView(appState: appState)
        let contentView = CursorFixingHostingView(rootView: overlayView)
        self.contentView = contentView
        
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak appState] event in
            if event.modifierFlags.contains(.option) {
                appState?.isOptionPressed = true
            } else {
                appState?.isOptionPressed = false
            }
            return event
        }
        
        // Add GLOBAL keyboard shortcut for focusing input field: Cmd+/
        // This works even when the app is not focused
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            // Check for Cmd+/ (forward slash)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
                DispatchQueue.main.async {
                    appState?.isVisible = true
                    appState?.shouldFocusInput = true
                }
            }
        }
        
        // Also add local monitor for when app IS focused
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            // Check for Cmd+/ (forward slash)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
                appState?.shouldFocusInput = true
                return nil // Consume the event
            }
            return event
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    func moveWindow(dx: CGFloat, dy: CGFloat, animate: Bool = true) {
        let currentOrigin = self.frame.origin
        let newOrigin = NSPoint(x: currentOrigin.x + dx, y: currentOrigin.y + dy)
        let newFrame = NSRect(origin: newOrigin, size: self.frame.size)
        
        if animate {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            })
        } else {
            self.setFrame(newFrame, display: true)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = self.frame.origin
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startMouse = dragStartMouseLocation,
              let startOrigin = dragStartWindowOrigin else {
            return
        }
        
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - startMouse.x
        let deltaY = currentMouse.y - startMouse.y
        
        self.setFrameOrigin(NSPoint(
            x: startOrigin.x + deltaX,
            y: startOrigin.y + deltaY
        ))
    }
}

class CursorFixingHostingView<Content: View>: NSHostingView<Content> {
    override func resetCursorRects() {
        // Discard any cursor rects set by subviews (like text fields)
        // and force the arrow cursor for the entire view.
        self.discardCursorRects()
        self.addCursorRect(self.bounds, cursor: .arrow)
    }
}
