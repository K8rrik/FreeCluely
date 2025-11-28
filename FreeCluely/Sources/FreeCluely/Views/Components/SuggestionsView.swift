import SwiftUI

struct SuggestionsView: View {
    @ObservedObject var appState: AppState
    
    // Define a palette of rich gradients
    private let gradients: [LinearGradient] = [
        LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.red.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.teal.opacity(0.8), Color.green.opacity(0.8)]), startPoint: .leading, endPoint: .trailing),
        LinearGradient(gradient: Gradient(colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.8)]), startPoint: .leading, endPoint: .trailing)
    ]
    
    private func getGradient(for suggestion: AppState.SmartSuggestion) -> LinearGradient {
        // Use the hash of the topic to consistently pick a gradient
        let index = abs(suggestion.topic.hashValue) % gradients.count
        return gradients[index]
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.suggestions) { suggestion in
                    Button(action: {
                        appState.activateSuggestion(suggestion)
                    }) {
                        Text(suggestion.topic)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                getGradient(for: suggestion)
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .frame(height: 40)
    }
}
