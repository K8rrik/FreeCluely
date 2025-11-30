import AppKit
import SwiftUI
import Combine

class TranscriptionWindowController: NSWindowController {
    private var appState: AppState
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState) {
        self.appState = appState
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.borderless, .fullSizeContentView], // Borderless for custom look
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar // Match OverlayWindow level
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true // Allow moving by background
        window.hidesOnDeactivate = false
        window.sharingType = .none // Exclude from screenshots
        
        let view = TranscriptionView(appState: appState)
        window.contentView = NSHostingView(rootView: view)
        
        super.init(window: window)
        
        // Observe visibility
        appState.$isVisible
            .sink { [weak self] isVisible in
                guard let self = self else { return }
                if isVisible {
                    if self.appState.isVoiceModeActive {
                        self.showWindow(nil)
                    }
                } else {
                    self.close()
                }
            }
            .store(in: &cancellables)
            
        // Observe inspectable state (Eye icon)
        appState.$isInspectable
            .sink { [weak self] isInspectable in
                self?.window?.sharingType = isInspectable ? .readOnly : .none
            }
            .store(in: &cancellables)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func alignToRightOf(window mainWindow: NSWindow?) {
        guard let mainWindow = mainWindow, let myWindow = self.window else { return }
        
        let mainFrame = mainWindow.frame
        let padding: CGFloat = 20
        
        // Position to the right of the main window
        let newOrigin = NSPoint(
            x: mainFrame.maxX + padding,
            y: mainFrame.maxY - myWindow.frame.height // Align tops
        )
        
        myWindow.setFrameOrigin(newOrigin)
    }
}
