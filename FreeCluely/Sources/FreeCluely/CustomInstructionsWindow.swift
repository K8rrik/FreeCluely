import SwiftUI
import AppKit

class CustomInstructionsWindow: NSWindow {
    init(mainWindow: NSWindow?) {
        // Calculate position below main window
        let width: CGFloat = 500
        let height: CGFloat = 280
        
        var x: CGFloat
        var y: CGFloat
        
        if let mainWindow = mainWindow {
            // Position below main window, centered horizontally
            x = mainWindow.frame.origin.x + (mainWindow.frame.width - width) / 2
            y = mainWindow.frame.origin.y - height - 10 // 10px gap
        } else {
            // Fallback to center of screen
            let screenRect = NSScreen.main?.frame ?? .zero
            x = (screenRect.width - width) / 2
            y = (screenRect.height - height) / 2
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
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        
        self.sharingType = .none
        
        let contentView = CustomInstructionsWindowContent(window: self)
        self.contentView = NSHostingView(rootView: contentView)
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

struct CustomInstructionsWindowContent: View {
    @State private var customInstructions: String = ""
    @State private var showSaveConfirmation: Bool = false
    weak var window: NSWindow?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Кастомные инструкции")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    window?.close()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.2))
            
            // Description
            Text("Эти инструкции будут добавлены к базовому промпту и учитываться при каждом запросе.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Text Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $customInstructions)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.05))
                    .padding(8)
                
                if customInstructions.isEmpty {
                    Text("Например:\n- Будь более кратким\n- Используй примеры\n- Предлагай альтернативы")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    customInstructions = ""
                    CustomInstructionsManager.shared.clearInstructions()
                    showSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showSaveConfirmation = false
                    }
                }) {
                    Text("Очистить")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if showSaveConfirmation {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 10))
                        Text("Сохранено!")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }
                
                Button(action: {
                    CustomInstructionsManager.shared.saveInstructions(customInstructions)
                    showSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showSaveConfirmation = false
                    }
                }) {
                    Text("Сохранить")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color.black.opacity(0.2))
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            customInstructions = CustomInstructionsManager.shared.loadInstructions()
        }
    }
}
