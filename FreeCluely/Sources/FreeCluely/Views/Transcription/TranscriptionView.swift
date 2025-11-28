import SwiftUI

struct TranscriptionView: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 0) {
            // Title / Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(!appState.liveTranscript.isEmpty ? .green : .green.opacity(0.5))
                        .scaleEffect(!appState.liveTranscript.isEmpty ? 1.05 : 1.0) // Subtle scale
                        .opacity(!appState.liveTranscript.isEmpty ? 1.0 : 0.7)
                        .animation(
                            !appState.liveTranscript.isEmpty ? 
                                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                                .default, 
                            value: !appState.liveTranscript.isEmpty
                        )
                    
                    Text("LIVE TRANSCRIPTION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green.opacity(0.6))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle()) // Make the whole header clickable
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content Area
            // Using a frame-based approach with clipped() for smooth animation
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            // History of transcription log - Show ALL history
                            ForEach(Array(appState.transcriptionLog.enumerated()), id: \.offset) { index, text in
                                Text(text)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("log-\(index)")
                            }
                            
                            // Live Interim Text
                            if !appState.liveTranscript.isEmpty {
                                Text(appState.liveTranscript)
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("live")
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)
                    }
                    .frame(height: 200) // Fixed height for the scrollable area
                    .onChange(of: appState.liveTranscript) { _ in
                        withAnimation {
                            proxy.scrollTo("live", anchor: .bottom)
                        }
                    }
                    .onChange(of: appState.transcriptionLog.count) { _ in
                        withAnimation {
                            proxy.scrollTo("live", anchor: .bottom)
                        }
                    }
                }
                .opacity(isExpanded ? 1 : 0) // Fade content in/out
            }
            .frame(height: isExpanded ? 200 : 0) // Animate height
            .clipped() // Clip content during animation
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isExpanded ? 12 : 4) // Animate vertical padding
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        // Apply animation to the container for smooth resizing
       
    }
}
