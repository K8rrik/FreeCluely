import SwiftUI
import AppKit
import Combine

class HistoryWindowController: NSWindow {
    private var cancellables = Set<AnyCancellable>()
    
    init(appState: AppState, mainWindow: NSWindow?) {
        // Calculate position to the right of main window
        let width: CGFloat = 320
        let height: CGFloat = 500
        
        var x: CGFloat
        var y: CGFloat
        
        if let mainWindow = mainWindow {
            // Position to the right of main window, aligned to top
            x = mainWindow.frame.maxX + 10 // 10px gap to the right
            y = mainWindow.frame.maxY - height // Align to top
        } else {
            // Fallback to top-right of screen
            let screenRect = NSScreen.main?.frame ?? .zero
            x = screenRect.maxX - width - 20
            y = screenRect.maxY - height - 40
        }
        
        super.init(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        
        self.sharingType = .none
        
        let contentView = HistoryView(appState: appState)
        self.contentView = NSHostingView(rootView: contentView)
        
        // Observe visibility
        appState.$isVisible
            .sink { [weak self] isVisible in
                if !isVisible {
                    self?.close()
                }
            }
            .store(in: &cancellables)
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func close() {
        super.close()
        self.orderOut(nil)
    }
}
