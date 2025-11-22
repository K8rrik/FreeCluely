import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var responseText: String = "" // Kept for compatibility if needed, but we should move to messages
    @Published var isLoading: Bool = false
    @Published var apiKey: String = ""
    @Published var model: String = "gemini-1.5-pro"
    @Published var isInspectable: Bool = false
    @Published var isVisible: Bool = true
    @Published var isOptionPressed: Bool = false
    
    @Published var history: [ChatSession] = []
    @Published var showHistory: Bool = false
    
    // Chat & Context
    @Published var lastCapturedImage: CGImage? = nil
    @Published var inputText: String = ""
    @Published var currentSession: ChatSession = ChatSession()
    
    init() {
        let env = ConfigLoader.loadEnv()
        if let key = env["GEMINI_API_KEY"] {
            self.apiKey = key
            print("AppState: Loaded API Key (length: \(key.count))")
        } else {
            print("AppState: No API Key found in .env")
        }
        if let modelEnv = env["GEMINI_MODEL"] {
            self.model = modelEnv
            print("AppState: Loaded Model from .env: \(modelEnv)")
        } else {
            print("AppState: Using default model: \(self.model)")
        }
        
        self.history = HistoryManager.shared.loadHistory()
    }
    
    func startNewSession() {
        self.currentSession = ChatSession()
        // Don't add to history yet, wait for content
    }
    
    func saveCurrentSession() {
        guard !currentSession.messages.isEmpty else { return }
        
        if let index = history.firstIndex(where: { $0.id == currentSession.id }) {
            history[index] = currentSession
        } else {
            history.insert(currentSession, at: 0)
        }
        HistoryManager.shared.saveHistory(history)
    }
    
    func deleteHistoryItem(at offsets: IndexSet) {
        self.history.remove(atOffsets: offsets)
        HistoryManager.shared.saveHistory(self.history)
    }
    
    func appendErrorMessage(_ error: Error, for messageId: UUID) {
        let errorMessage: String
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "⚠️ Нет подключения к интернету. Проверьте соединение."
            case .timedOut:
                errorMessage = "⚠️ Время ожидания истекло. Сервер не отвечает."
            case .cannotFindHost, .cannotConnectToHost:
                errorMessage = "⚠️ Не удалось подключиться к серверу."
            default:
                errorMessage = "⚠️ Ошибка сети: \(urlError.localizedDescription)"
            }
        } else {
            errorMessage = "⚠️ Ошибка: \(error.localizedDescription)"
        }
        
        if let index = self.currentSession.messages.firstIndex(where: { $0.id == messageId }) {
            self.currentSession.messages[index].text = errorMessage
        } else {
            let aiMessage = ChatMessage(id: messageId, role: .ai, text: errorMessage)
            self.currentSession.messages.append(aiMessage)
        }
    }
    
    func sendChatMessage() {
        guard !inputText.isEmpty else { return }
        
        let messageText = inputText
        inputText = "" // Clear input immediately
        
        // Add user message
        let userMessage = ChatMessage(role: .user, text: messageText)
        currentSession.messages.append(userMessage)
        
        // Prepare ID for the incoming AI message
        let aiMessageId = UUID()
        
        Task {
            await MainActor.run {
                self.isLoading = true
            }
            
            do {
                let stream = GeminiClient.shared.streamRequest(
                    history: self.currentSession.messages,
                    image: lastCapturedImage,
                    apiKey: apiKey,
                    modelName: model
                )
                
                for try await text in stream {
                    await MainActor.run {
                        if let index = self.currentSession.messages.firstIndex(where: { $0.id == aiMessageId }) {
                            self.currentSession.messages[index].text += text
                        } else {
                            let aiMessage = ChatMessage(id: aiMessageId, role: .ai, text: text)
                            self.currentSession.messages.append(aiMessage)
                        }
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.saveCurrentSession()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.appendErrorMessage(error, for: aiMessageId)
                }
            }
        }
    }
}
