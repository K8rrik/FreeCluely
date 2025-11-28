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
    @Published var shouldFocusInput: Bool = false
    
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
            errorMessage = "⚠️ API Error (\(geminiError.error.code)): \(geminiError.error.message)"
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "⚠️ No internet connection. Check your connection."
            case .timedOut:
                errorMessage = "⚠️ Request timed out. Server is not responding."
            case .cannotFindHost, .cannotConnectToHost:
                errorMessage = "⚠️ Failed to connect to server."
            default:
                errorMessage = "⚠️ Network Error: \(urlError.localizedDescription)"
            }
        } else {
            errorMessage = "⚠️ Error: \(error.localizedDescription)"
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
    
    // MARK: - Voice Mode
    
    @Published var isVoiceModeActive: Bool = false
    @Published var liveTranscript: String = ""
    
    private var systemAudioService: DeepgramService?
    private var micAudioService: DeepgramService?
    
    func toggleVoiceMode() {
        if isVoiceModeActive {
            stopVoiceMode()
        } else {
            startVoiceMode()
        }
    }
    
    private func startVoiceMode() {
        guard let deepgramKey = ConfigLoader.loadEnv()["DEEPGRAM_API_KEY"], !deepgramKey.isEmpty else {
            print("Deepgram API Key missing")
            let errorMsg = ChatMessage(role: .ai, text: "⚠️ Deepgram API Key missing. Please add DEEPGRAM_API_KEY to your .env file.")
            currentSession.messages.append(errorMsg)
            return
        }
        
        isVoiceModeActive = true
        
        // Initialize Services
        systemAudioService = DeepgramService()
        // micAudioService = DeepgramService() // Disabled by user request
        
        // Connect to Deepgram
        systemAudioService?.connect(apiKey: deepgramKey)
        // micAudioService?.connect(apiKey: deepgramKey) // Disabled by user request
        
        // Configure Audio Capture Callbacks
        if #available(macOS 13.0, *) {
            AudioCaptureManager.shared.onSystemAudioData = { [weak self] data in
                self?.systemAudioService?.sendAudioData(data)
            }
            
            // AudioCaptureManager.shared.onMicrophoneAudioData = { [weak self] data in
            //     self?.micAudioService?.sendAudioData(data)
            // }
        }
        
        // Start Audio Capture
        Task {
            if #available(macOS 13.0, *) {
                do {
                    try await AudioCaptureManager.shared.startCapture()
                } catch {
                    await MainActor.run {
                        self.isVoiceModeActive = false
                        self.appendErrorMessage(error, for: UUID())
                    }
                }
            } else {
                await MainActor.run {
                    self.isVoiceModeActive = false
                    let errorMsg = ChatMessage(role: .ai, text: "⚠️ Voice Mode requires macOS 13.0 or later.")
                    self.currentSession.messages.append(errorMsg)
                }
            }
        }
        
        // Listen for transcripts (System)
        Task {
            guard let stream = systemAudioService?.transcriptStream else { return }
            for await event in stream {
                await MainActor.run {
                    self.handleTranscriptEvent(event, source: "Heard")
                }
            }
        }
        
        // Listen for transcripts (Mic)
        // Task {
        //     guard let stream = micAudioService?.transcriptStream else { return }
        //     for await event in stream {
        //         await MainActor.run {
        //             self.handleTranscriptEvent(event, source: "You")
        //         }
        //     }
        // }
    }
    
    private func stopVoiceMode() {
        isVoiceModeActive = false
        if #available(macOS 13.0, *) {
            AudioCaptureManager.shared.stopCapture()
            AudioCaptureManager.shared.onSystemAudioData = nil
            AudioCaptureManager.shared.onMicrophoneAudioData = nil
        }
        systemAudioService?.disconnect()
        micAudioService?.disconnect()
        systemAudioService = nil
        micAudioService = nil
        liveTranscript = ""
    }
    
    private func handleTranscriptEvent(_ event: TranscriptEvent, source: String) {
        // Update live transcript preview
        if !event.isFinal {
            self.liveTranscript = event.text
        } else {
            self.liveTranscript = ""
            let message = ChatMessage(role: .user, text: event.text)
            self.currentSession.messages.append(message)
        }
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
