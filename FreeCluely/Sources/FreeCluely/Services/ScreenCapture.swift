import AppKit
import CoreGraphics
import VideoToolbox

class ScreenCapture {
    static let shared = ScreenCapture()
    
    private init() {}
    
    func captureAndAnalyze(appState: AppState) async {
        // Prevent multiple simultaneous requests
        if await MainActor.run(body: { appState.isLoading }) {
            return
        }

        await MainActor.run {
            // Do NOT start a new session, append to existing one
            // appState.startNewSession() 
            appState.isLoading = true
        }
        
        guard let image = captureScreen() else {
            await MainActor.run {
                appState.isLoading = false
                let errorMessage = "⚠️ Failed to capture screenshot."
                let errorMsg = ChatMessage(role: .ai, text: errorMessage)
                appState.currentSession.messages.append(errorMsg)
            }
            return
        }
        
        await MainActor.run {

            
            var imageData: Data? = nil
            if let resized = image.resize(maxDimension: 1024),
               let data = resized.jpegData(compressionQuality: 0.7) {
                imageData = data
            }
            
            let userMessage = ChatMessage(role: .user, text: "Screenshot sent. Analyzing...", imageData: imageData)
            appState.currentSession.messages.append(userMessage)
        }
        
        let apiKey = await appState.apiKey
        let model = await appState.model
        let history = await appState.currentSession.messages
        
        // Prepare ID for the incoming AI message
        let aiMessageId = UUID()
        
        let task = Task {
            do {
                // Use history
                let stream = GeminiClient.shared.streamRequest(
                    history: history,
                    image: nil, // Image is now in history
                    apiKey: apiKey,
                    model: model,
                    generationConfig: GenerationConfig(
                        temperature: nil,
                        topP: nil,
                        topK: nil,
                        maxOutputTokens: 65536,
                        candidateCount: 1,
                        thinkingConfig: ThinkingConfig(includeThoughts: true, thinkingLevel: "high")
                    ),
                    safetySettings: [
                        SafetySetting(category: .harassment, threshold: .blockNone),
                        SafetySetting(category: .hateSpeech, threshold: .blockNone),
                        SafetySetting(category: .sexuallyExplicit, threshold: .blockNone),
                        SafetySetting(category: .dangerousContent, threshold: .blockNone)
                    ],
                    tools: [
                        Tool(googleSearch: true)
                    ]
                )
                
                for try await update in stream {
                    await MainActor.run {
                        if let index = appState.currentSession.messages.firstIndex(where: { $0.id == aiMessageId }) {
                            if let text = update.text {
                                appState.currentSession.messages[index].text += text
                            }
                            if let thought = update.thought {
                                if appState.currentSession.messages[index].thought == nil {
                                    appState.currentSession.messages[index].thought = ""
                                }
                                appState.currentSession.messages[index].thought! += thought
                            }
                        } else {
                            let aiMessage = ChatMessage(
                                id: aiMessageId,
                                role: .ai,
                                text: update.text ?? "",
                                thought: update.thought
                            )
                            appState.currentSession.messages.append(aiMessage)
                        }
                    }
                }
                
                await MainActor.run {
                    appState.isLoading = false
                    appState.saveCurrentSession()
                }
            } catch {
                if error is CancellationError {
                    return
                }
                await MainActor.run {
                    appState.isLoading = false
                    appState.appendErrorMessage(error, for: aiMessageId)
                }
            }
        }
        
        await appState.setCurrentTask(task)
        await task.value
    }
    
    private func captureScreen() -> CGImage? {
        // Capture main display
        _ = CGMainDisplayID()
        
        // Create image, excluding our own window if possible.
        // Since our window is sharingType = .none, it should be automatically excluded!
        guard let image = CGWindowListCreateImage(
            CGRect.infinite,
            .optionOnScreenBelowWindow,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return nil
        }
        
        return image
    }
}
