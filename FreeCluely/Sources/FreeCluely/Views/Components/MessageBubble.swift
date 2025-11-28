import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    
    @State private var isThinkingExpanded: Bool = true
    @State private var hasCollapsedThinking: Bool = false

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 12))
                        .padding(8)
                        .background(
                            message.text.starts(with: "[Heard]:") ? Color.orange.opacity(0.8) :
                            message.text.starts(with: "[You]:") ? Color.green.opacity(0.8) :
                            Color.blue.opacity(0.8)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(AppConstants.UI.messageCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppConstants.UI.messageCornerRadius)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    if let imageData = message.imageData, let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 300)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .frame(maxWidth: 400, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let thought = message.thought, !thought.isEmpty {
                        DisclosureGroup("Thinking Process", isExpanded: $isThinkingExpanded) {
                            Text(thought)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accentColor(.white.opacity(0.6))
                        .font(.system(size: 12, weight: .bold))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    if !message.text.isEmpty {
                        MarkdownView(text: message.text)
                    }
                }
                .padding(8)
                .background(message.isAmbient ? Color.purple.opacity(0.6) : Color.black.opacity(0.6)) // Darker background for AI, Purple for Ambient
                .cornerRadius(AppConstants.UI.messageCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.UI.messageCornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    if !message.text.isEmpty {
                        isThinkingExpanded = false
                        hasCollapsedThinking = true
                    }
                }
                .onChange(of: message.text) { newText in
                    if !newText.isEmpty && !hasCollapsedThinking {
                        withAnimation {
                            isThinkingExpanded = false
                        }
                        hasCollapsedThinking = true
                    }
                }
                Spacer()
            }
        }
    }
}
