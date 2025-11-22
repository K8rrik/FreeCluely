import AppKit
import CoreGraphics
import VideoToolbox

class ScreenCapture {
    static let shared = ScreenCapture()
    
    private init() {}
    
    func captureAndAnalyze(appState: AppState) async {
        await MainActor.run {
            // Start a new session for a fresh capture
            appState.startNewSession()
            appState.isLoading = true
            // Add placeholder for "Analyzing..." state or just wait for stream?
            // Let's add a system/user message indicating capture?
            // Or just let the first AI message be the analysis.
            // Let's add a "Screenshot captured" user message for context in UI?
            // Actually, the user didn't type anything. Let's just have the AI response.
            // But we need a placeholder to show loading state if we want to be fancy,
            // or just rely on appState.isLoading overlay.
            
            // Let's add an AI message placeholder immediately so the UI shows something appearing.
            // Removed to allow loading indicator to show
        }
        
        guard let image = captureScreen() else {
            await MainActor.run {
                appState.isLoading = false
                let errorMessage = "⚠️ Не удалось сделать скриншот."
                let errorMsg = ChatMessage(role: .ai, text: errorMessage)
                appState.currentSession.messages.append(errorMsg)
            }
            return
        }
        
        await MainActor.run {
            appState.lastCapturedImage = image
            let userMessage = ChatMessage(role: .user, text: "Скриншот отправлен. Проанализируй его.")
            appState.currentSession.messages.append(userMessage)
        }
        
        let apiKey = await appState.apiKey
        let model = await appState.model
        let history = await appState.currentSession.messages
        
        // Prepare ID for the incoming AI message
        let aiMessageId = UUID()
        
        do {
            // Use history
            let stream = GeminiClient.shared.streamRequest(history: history, image: image, apiKey: apiKey, modelName: model)
            
            for try await text in stream {
                await MainActor.run {
                    if let index = appState.currentSession.messages.firstIndex(where: { $0.id == aiMessageId }) {
                        appState.currentSession.messages[index].text += text
                    } else {
                        let aiMessage = ChatMessage(id: aiMessageId, role: .ai, text: text)
                        appState.currentSession.messages.append(aiMessage)
                    }
                }
            }
            
            await MainActor.run {
                appState.isLoading = false
                appState.saveCurrentSession()
            }
        } catch {
            await MainActor.run {
                appState.isLoading = false
                appState.appendErrorMessage(error, for: aiMessageId)
            }
        }
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
