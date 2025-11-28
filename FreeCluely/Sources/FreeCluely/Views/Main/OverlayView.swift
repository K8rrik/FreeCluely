import SwiftUI

import AppKit

struct OverlayView: View {
    @ObservedObject var appState: AppState
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified Window Container
            VStack(spacing: 0) {
                headerView
                messagesView
                inputView
            }
            .frame(minHeight: 100)

            .background(Color.black.opacity(0.8))
            .cornerRadius(AppConstants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            // Suggestions Container attached to the bottom of the main window
            if !appState.suggestions.isEmpty {
                SuggestionsView(appState: appState)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .overlay(
            ResizeHandleView()
                .frame(width: 30, height: 30)
                .contentShape(Rectangle()),
            alignment: .bottomTrailing
        )
    }
    
    var headerView: some View {
        HStack {
            // Left side: Spacer (Hints moved to buttons)
            // Left side: Logo
            HStack(spacing: 8) {
                Text(AppConstants.appName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("⌘/")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.leading, 4)
            
            Spacer()
            

            
            // Right side: Action Buttons
            HStack(spacing: 8) {
                // Clear Button
                VStack(spacing: 2) {
                    Text("⌘⇧C")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        appState.startNewSession()
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(IconButtonStyle())
                }
                
                // Settings Button (Custom Instructions)
                VStack(spacing: 2) {
                    Text("⌘⇧I")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        appState.toggleCustomInstructionsWindow()
                    }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(IconButtonStyle())
                }
                
                // History Button
                VStack(spacing: 2) {
                    Text("⌘⇧H")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        appState.toggleHistoryWindow()
                    }) {
                        Image(systemName: "clock")
                    }
                    .buttonStyle(IconButtonStyle())
                }
                
                // Close Button (Hide)
                VStack(spacing: 2) {
                    Text("⌘⇧W")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        appState.isVisible = false
                    }) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(IconButtonStyle())
                }
                
                // Voice Mode Button
                VStack(spacing: 2) {
                    Text("Voice")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        appState.toggleVoiceMode()
                    }) {
                        Image(systemName: appState.isVoiceModeActive ? "mic.fill" : "mic.slash")
                            .foregroundColor(appState.isVoiceModeActive ? .red : .white)
                    }
                    .buttonStyle(IconButtonStyle())
                }
                
                // Eye & Power Buttons (with shared Hold ⌥ label)
                VStack(spacing: 2) {
                    Text("Hold ⌥")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    HStack(spacing: 8) {
                        // Eye Button
                        Button(action: {
                            appState.isInspectable.toggle()
                        }) {
                            Image(systemName: appState.isInspectable ? "eye" : "eye.slash")
                                .foregroundColor(appState.isInspectable ? .green : .white.opacity(0.6))
                        }
                        .buttonStyle(IconButtonStyle())
                        .disabled(!appState.isOptionPressed)
                        .opacity(appState.isOptionPressed ? 1.0 : 0.5)
                        
                        // Power Button (Quit)
                        Button(action: {
                            NSApplication.shared.terminate(nil)
                        }) {
                            Image(systemName: "power")
                        }
                        .buttonStyle(IconButtonStyle())
                        .disabled(!appState.isOptionPressed)
                        .opacity(appState.isOptionPressed ? 1.0 : 0.5)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.leading)
        .padding(.trailing, 8)
    }
    
    @ViewBuilder
    var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.currentSession.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if appState.isLoading && (appState.currentSession.messages.isEmpty || appState.currentSession.messages.last?.role == .user) {
                        HStack {
                            ThinkingIndicator()
                            Spacer()
                        }
                        .padding(.leading, 8)
                        .transition(.opacity)
                        .id("loading-indicator")
                    }
                    

                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            .onChange(of: appState.currentSession.messages.last?.text) { _ in
                if let lastId = appState.currentSession.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: appState.isLoading) { loading in
                if loading {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo("loading-indicator", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    var inputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image Preview
            
            
            HStack {
                TextField(appState.isLoading ? AppConstants.Placeholders.loading : AppConstants.Placeholders.inputDefault, text: $appState.inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(appState.isLoading ? 0.05 : 0.1))
                    .cornerRadius(8)
                    .disabled(appState.isLoading)
                    .focused($isInputFocused)
                    .onSubmit {
                        appState.sendChatMessage()
                    }
                    .onChange(of: appState.shouldFocusInput) { shouldFocus in
                        if shouldFocus {
                            isInputFocused = true
                            appState.shouldFocusInput = false
                        }
                    }

            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    

    

    
}


