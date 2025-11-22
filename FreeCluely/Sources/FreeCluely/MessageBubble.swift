import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                Text(message.text)
                    .font(.system(size: 12))
                    .padding(8)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxWidth: 400, alignment: .trailing)
            } else {
                MarkdownView(text: message.text)
                    .padding(8)
                    .background(Color.black.opacity(0.6)) // Darker background for AI
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
        }
    }
}
