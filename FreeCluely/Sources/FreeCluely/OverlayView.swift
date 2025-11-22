import SwiftUI

struct OverlayView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Unified Window Container
            VStack(spacing: 0) {
                headerView
                messagesView
                inputView
            }
            .frame(minHeight: 140)

            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .overlay(historyOverlay)
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
            Text("FreeCluely")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .padding(.leading, 4)
            
            Spacer()
            

            
            // Right side: Action Buttons
            HStack(spacing: 16) {
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
                
                // History Button
                VStack(spacing: 2) {
                    Text("⌘⇧H")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        withAnimation {
                            appState.showHistory.toggle()
                        }
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
                
                // Eye Button
                VStack(spacing: 2) {
                    Text("Hold ⌥")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                    Button(action: {
                        appState.isInspectable.toggle()
                    }) {
                        Image(systemName: appState.isInspectable ? "eye" : "eye.slash")
                            .foregroundColor(appState.isInspectable ? .green : .white.opacity(0.6))
                    }
                    .buttonStyle(IconButtonStyle())
                    .disabled(!appState.isOptionPressed)
                    .opacity(appState.isOptionPressed ? 1.0 : 0.5)
                }
                
                // Power Button (Quit)
                VStack(spacing: 2) {
                     Text("Hold ⌥")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
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
        .padding(.vertical, 8)
        .padding(.horizontal)
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
                .padding(.bottom, 8)
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
        HStack {
            TextField("Анализ экрана (⌘⇧A) или Спросите что-нибудь...", text: $appState.inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .onSubmit {
                    appState.sendChatMessage()
                }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    

    
    @ViewBuilder
    var historyOverlay: some View {
        if appState.showHistory {
            HistoryView(appState: appState)
                .transition(.opacity)
                .padding(.trailing, 20)
                .padding(.top, 260) // Increased top padding to push it down below header/input area
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(0.6))
            .frame(width: 20, height: 20)
            .padding(6)
            .background(Color.white.opacity(configuration.isPressed ? 0.2 : 0.0))
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}


