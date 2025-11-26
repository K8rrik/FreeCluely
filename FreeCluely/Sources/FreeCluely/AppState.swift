import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var responseText: String = "" // Kept for compatibility if needed, but we should move to messages
    @Published var isLoading: Bool = false
    @Published var apiKey: String = ""
    @Published var model: GeminiModel = .gemini3ProPreview
    @Published var isInspectable: Bool = false
    @Published var isVisible: Bool = true
    @Published var isOptionPressed: Bool = false
    
    @Published var history: [ChatSession] = []
    
    // Separate Windows
    weak var mainWindow: NSWindow?
    var historyWindow: HistoryWindowController?
    var customInstructionsWindow: CustomInstructionsWindow?
    
    // Chat & Context

    @Published var inputText: String = ""
    @Published var currentSession: ChatSession = ChatSession()
    
    private var currentTask: Task<Void, Never>?
    
    init() {
        let env = ConfigLoader.loadEnv()
        if let key = env["GEMINI_API_KEY"] {
            self.apiKey = key
            print("AppState: Loaded API Key (length: \(key.count))")
        } else {
            print("AppState: No API Key found in .env")
        }
        if let modelEnv = env["GEMINI_MODEL"], let loadedModel = GeminiModel(rawValue: modelEnv) {
            self.model = loadedModel
            print("AppState: Loaded Model from .env: \(modelEnv)")
        } else {
            print("AppState: Using default model: \(self.model.rawValue)")
        }
        
        self.history = HistoryManager.shared.loadHistory()
    }
    
    func startNewSession() {
        currentTask?.cancel()
        currentTask = nil
        
        // Save the partial session before clearing
        saveCurrentSession()
        
        self.currentSession = ChatSession()

        self.isLoading = false // Reset loading state for new chat
        // Don't add to history yet, wait for content
    }
    
    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        self.isLoading = false
    }
    
    func setCurrentTask(_ task: Task<Void, Never>) {
        currentTask?.cancel()
        currentTask = task
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
        
        if let geminiError = error as? GeminiError {
            errorMessage = "⚠️ Ошибка API (\(geminiError.error.code)): \(geminiError.error.message)"
        } else if let urlError = error as? URLError {
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

        
        let userMessage = ChatMessage(role: .user, text: messageText, imageData: nil)
        currentSession.messages.append(userMessage)
        
        // Prepare ID for the incoming AI message
        let aiMessageId = UUID()
        

        
        let task = Task {
            await MainActor.run {
                self.isLoading = true
            }
            
            do {
                let stream = GeminiClient.shared.streamRequest(
                    history: self.currentSession.messages,
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
                        if let index = self.currentSession.messages.firstIndex(where: { $0.id == aiMessageId }) {
                            if let text = update.text {
                                self.currentSession.messages[index].text += text
                            }
                            if let thought = update.thought {
                                if self.currentSession.messages[index].thought == nil {
                                    self.currentSession.messages[index].thought = ""
                                }
                                self.currentSession.messages[index].thought! += thought
                            }
                        } else {
                            let aiMessage = ChatMessage(
                                id: aiMessageId,
                                role: .ai,
                                text: update.text ?? "",
                                thought: update.thought
                            )
                            self.currentSession.messages.append(aiMessage)
                        }
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.saveCurrentSession()
                }
            } catch {
                if error is CancellationError {
                    // Task was cancelled, do nothing (don't show error in new chat)
                    return
                }
                await MainActor.run {
                    self.isLoading = false
                    self.appendErrorMessage(error, for: aiMessageId)
                }
            }
        }
        
        self.setCurrentTask(task)
    }
    
    // MARK: - Window Management
    
    func toggleHistoryWindow() {
        if let window = historyWindow, window.isVisible {
            window.close()
        } else {
            if historyWindow == nil {
                historyWindow = HistoryWindowController(appState: self, mainWindow: mainWindow)
            }
            historyWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    func toggleCustomInstructionsWindow() {
        if let window = customInstructionsWindow, window.isVisible {
            window.close()
        } else {
            if customInstructionsWindow == nil {
                customInstructionsWindow = CustomInstructionsWindow(mainWindow: mainWindow)
            }
            customInstructionsWindow?.makeKeyAndOrderFront(nil)
        }
    }
}
