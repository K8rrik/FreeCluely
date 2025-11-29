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
    
    // Smart Assistant
    @Published var fastModel: GeminiModel = .gemini25Flash // Updated default to 2.5 Flash
    private var contextBuffer: String = ""
    private var contextHistory: [String] = [] // История последних фраз для скользящего окна
    private var lastAnalysisTime: Date = Date()
    private var isAnalyzing: Bool = false
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 3.0 // 3 секунды после последней речи
    private let minimumContextLength: Int = 50 // Минимум символов для анализа
    private let maxContextLength: Int = 500 // Максимум для одного анализа
    private var recentTopics: Set<String> = [] // Для дедупликации
    private let maxRecentTopics = 10
    private let maxSuggestions = 3 // Максимум одновременных suggestions
    
    // Smart Suggestions
    struct SmartSuggestion: Identifiable, Codable {
        let id: UUID
        let topic: String
        let answer: String // Changed from hiddenQuestion to answer
        let timestamp: Date
        
        init(id: UUID = UUID(), topic: String, answer: String, timestamp: Date = Date()) {
            self.id = id
            self.topic = topic
            self.answer = answer
            self.timestamp = timestamp
        }
    }
    
    @Published var suggestions: [SmartSuggestion] = []
    private var suggestionTimers: [UUID: Timer] = [:]
    
    @Published var history: [ChatSession] = []
    
    // Separate Windows
    weak var mainWindow: NSWindow?
    var historyWindow: HistoryWindowController?
    var customInstructionsWindow: CustomInstructionsWindow?
    var transcriptionWindow: TranscriptionWindowController?
    
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
        
        // Load Fast Model
        if let fastModelEnv = env["GEMINI_FAST_MODEL"], let loadedFastModel = GeminiModel(rawValue: fastModelEnv) {
            self.fastModel = loadedFastModel
            print("AppState: Loaded Fast Model from .env: \(fastModelEnv)")
        } else {
            print("AppState: Using default fast model: \(self.fastModel.rawValue)")
        }
    }
    
    func cycleModel() {
        let models: [GeminiModel] = [.gemini3ProPreview, .gemini25Pro, .gemini25Flash]
        if let currentIndex = models.firstIndex(of: self.model) {
            let nextIndex = (currentIndex + 1) % models.count
            self.model = models[nextIndex]
        } else {
            self.model = .gemini3ProPreview
        }
        print("AppState: Switched model to \(self.model.rawValue)")
    }
    
    func setModel(_ model: GeminiModel) {
        self.model = model
        print("AppState: Set model to \(self.model.rawValue)")
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
                    generationConfig: self.model.generationConfig,
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
    @Published var transcriptionLog: [String] = []
    
    
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
        
        // Show Transcription Window
        toggleTranscriptionWindow(show: true)
        
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
        
        // Hide Transcription Window
        toggleTranscriptionWindow(show: false)
    }
    
    private func handleTranscriptEvent(_ event: TranscriptEvent, source: String) {
        // Update live transcript preview
        if !event.isFinal {
            self.liveTranscript = event.text
        } else {
            self.liveTranscript = ""
            // Keep in transcription log only, do not send to main chat automatically
            if !event.text.isEmpty {
                self.transcriptionLog.append(event.text)
                
                // Smart Assistant Logic with Debouncing
                // Добавляем в историю
                self.contextHistory.append(event.text)
                if self.contextHistory.count > 10 { // Храним последние 10 фраз
                    self.contextHistory.removeFirst()
                }
                
                // Обновляем буфер (скользящее окно)
                self.contextBuffer = self.contextHistory.joined(separator: " ")
                if self.contextBuffer.count > self.maxContextLength {
                    // Обрезаем с начала, сохраняя последние фразы
                    let words = self.contextBuffer.split(separator: " ")
                    self.contextBuffer = words.suffix(50).joined(separator: " ")
                }
                
                // Отменяем предыдущий таймер и создаем новый (дебаунсинг)
                self.debounceTimer?.invalidate()
                self.debounceTimer = Timer.scheduledTimer(withTimeInterval: self.debounceInterval, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.analyzeContextAndReply()
                    }
                }
            }
        }
    }
    
    private func analyzeContextAndReply() {
        guard !isAnalyzing else {
            print("⏳ Smart Assistant: Already analyzing, skipping...")
            return
        }
        
        let currentContext = self.contextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard currentContext.count >= minimumContextLength else {
            print("📏 Smart Assistant: Context too short (\(currentContext.count) chars), minimum is \(minimumContextLength)")
            return
        }
        
        print("🔍 Smart Assistant: Starting analysis...")
        print("📝 Context (\(currentContext.count) chars): \(currentContext.prefix(100))...")
        print("📚 Recent topics: \(recentTopics.isEmpty ? "(none)" : recentTopics.joined(separator: ", "))")
        print("💡 Current suggestions count: \(suggestions.count)/\(maxSuggestions)")
        
        isAnalyzing = true
        
        Task {
            do {
                // Construct the improved prompt for JSON output
                let recentTopicsText = recentTopics.isEmpty ? "(нет)" : recentTopics.joined(separator: ", ")
                
                let systemPrompt = """
                Ты - умный ассистент, который слушает разговор и помогает ТОЛЬКО когда это действительно нужно.
                
                ВАЖНО: Генерируй suggestions ТОЛЬКО для:
                - Явных вопросов или quiz вопросов
                - Технических обсуждений, требующих фактов или справочной информации
                - Тем, где пользователю реально может понадобиться помощь
                
                НЕ создавай suggestions для:
                - Casual болтовни или small talk
                - Общих фраз без конкретного вопроса
                - Контекста, который уже был покрыт ранее
                - Неполных мыслей или обрывков фраз
                
                ВЫВОД В ФОРМАТЕ JSON:
                {
                    "suggestions": [
                        {
                            "topic": "Краткое название темы (2-4 слова)",
                            "answer": "Краткий, но полный ответ (максимум 2-3 предложения)",
                            "confidence": 0.85
                        }
                    ]
                }
                
                Правила:
                1. Максимум 2 suggestions за раз (только самые важные и релевантные)
                2. "topic" должен быть уникальным и конкретным (2-4 слова)
                3. "answer" должен быть кратким (50-100 слов максимум)
                4. "confidence" - твоя уверенность в релевантности (0.0-1.0), генерируй только если >= 0.7
                5. Если темы похожи, объедини их в одну
                6. НЕ дублируй темы из списка ранее обсужденных
                
                Контекст разговора:
                \(currentContext)
                
                Ранее обсужденные темы (НЕ дублируй их):
                \(recentTopicsText)
                """
                
                let analysisMessages = [ChatMessage(role: .user, text: systemPrompt)]
                
                let stream = GeminiClient.shared.streamRequest(
                    history: analysisMessages,
                    apiKey: apiKey,
                    model: fastModel,
                    generationConfig: fastModel.generationConfig
                )
                
                var fullResponse = ""
                for try await update in stream {
                    if let text = update.text {
                        fullResponse += text
                    }
                }
                
                let cleanedResponse = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                
                print("Smart Suggestion Raw: '\(cleanedResponse)'")
                
                if let data = cleanedResponse.data(using: .utf8) {
                    struct SuggestionResponse: Decodable {
                        struct Item: Decodable {
                            let topic: String
                            let answer: String
                            let confidence: Double?
                        }
                        let suggestions: [Item]
                    }
                    
                    let response = try JSONDecoder().decode(SuggestionResponse.self, from: data)
                    
                    print("🎯 Smart Assistant: Received \(response.suggestions.count) raw suggestions")
                    
                    // Фильтруем по confidence и дублям
                    let filteredSuggestions = response.suggestions.filter { item in
                        // Проверяем confidence
                        if let confidence = item.confidence, confidence < 0.7 {
                            print("   ⚠️ Filtered out '\(item.topic)' - low confidence (\(confidence))")
                            return false
                        }
                        
                        // Проверяем на дубли с текущими suggestions
                        let normalizedTopic = item.topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        for existing in self.suggestions {
                            let existingNormalized = existing.topic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            if existingNormalized.contains(normalizedTopic) || normalizedTopic.contains(existingNormalized) {
                                print("   ⚠️ Filtered out '\(item.topic)' - duplicate of existing '\(existing.topic)'")
                                return false
                            }
                        }
                        
                        // Проверяем на недавние темы
                        for recentTopic in self.recentTopics {
                            let recentNormalized = recentTopic.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            if recentNormalized.contains(normalizedTopic) || normalizedTopic.contains(recentNormalized) {
                                print("   ⚠️ Filtered out '\(item.topic)' - duplicate of recent topic '\(recentTopic)'")
                                return false
                            }
                        }
                        
                        return true
                    }
                    
                    // Ограничиваем количество добавляемых suggestions
                    let availableSlots = max(0, self.maxSuggestions - self.suggestions.count)
                    let suggestionsToAdd = Array(filteredSuggestions.prefix(availableSlots))
                    
                    if !suggestionsToAdd.isEmpty {
                        await MainActor.run {
                            print("✅ Smart Assistant: Adding \(suggestionsToAdd.count) suggestions")
                            
                            // НЕ очищаем буфер полностью, сохраняем последнюю фразу для контекста
                            if let lastPhrase = self.contextHistory.last {
                                self.contextBuffer = lastPhrase
                            } else {
                                self.contextBuffer = ""
                            }
                            
                            for (index, item) in suggestionsToAdd.enumerated() {
                                let newSuggestion = SmartSuggestion(
                                    topic: item.topic,
                                    answer: item.answer
                                )
                                self.suggestions.append(newSuggestion)
                                self.recentTopics.insert(item.topic)
                                
                                // Ограничиваем размер recentTopics
                                if self.recentTopics.count > self.maxRecentTopics {
                                    if let first = self.recentTopics.first {
                                        self.recentTopics.remove(first)
                                    }
                                }
                                
                                print("   \(index + 1). '\(item.topic)' (confidence: \(item.confidence ?? 1.0))")
                                
                                // Schedule removal
                                self.scheduleSuggestionRemoval(for: newSuggestion.id)
                            }
                        }
                    } else {
                        print("ℹ️ Smart Assistant: No suggestions added (filtered or slots full)")
                        // Если нет новых suggestions и буфер большой, подрезаем его
                        if self.contextBuffer.count > self.maxContextLength {
                            let words = self.contextBuffer.split(separator: " ")
                            self.contextBuffer = words.suffix(30).joined(separator: " ")
                        }
                    }
                }
                
            } catch {
                print("Smart Suggestion Error: \(error)")
            }
            
            self.isAnalyzing = false
        }
    }
    
    private func scheduleSuggestionRemoval(for id: UUID) {
        // Schedule removal after 20 seconds (увеличено с 10 для лучшего UX)
        let timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Находим suggestion для удаления topic из recent
                if let suggestion = self?.suggestions.first(where: { $0.id == id }) {
                    self?.recentTopics.remove(suggestion.topic)
                    print("🗑️ Smart Assistant: Removed suggestion '\(suggestion.topic)' after timeout")
                }
                
                withAnimation {
                    self?.suggestions.removeAll { $0.id == id }
                }
                self?.suggestionTimers.removeValue(forKey: id)
            }
        }
        suggestionTimers[id] = timer
    }
    
    func activateSuggestion(_ suggestion: SmartSuggestion) {
        print("👆 Smart Assistant: User activated suggestion '\(suggestion.topic)'")
        
        // Invalidate timer if suggestion is activated early
        suggestionTimers[suggestion.id]?.invalidate()
        suggestionTimers.removeValue(forKey: suggestion.id)

        // Remove suggestion immediately
        withAnimation {
            self.suggestions.removeAll { $0.id == suggestion.id }
        }
        
        // Keep topic in recentTopics to prevent re-generation
        // (already added when created, so no action needed)
        
        // Directly append the pre-calculated answer
        let aiMessage = ChatMessage(role: .ai, text: suggestion.answer, isAmbient: true)
        self.currentSession.messages.append(aiMessage)
        self.saveCurrentSession()
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
                customInstructionsWindow = CustomInstructionsWindow(appState: self, mainWindow: mainWindow)
            }
            customInstructionsWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    func toggleTranscriptionWindow(show: Bool? = nil) {
        let shouldShow = show ?? (transcriptionWindow == nil || !transcriptionWindow!.window!.isVisible)
        
        if shouldShow {
            if transcriptionWindow == nil {
                transcriptionWindow = TranscriptionWindowController(appState: self)
            }
            transcriptionWindow?.showWindow(nil)
            transcriptionWindow?.alignToRightOf(window: mainWindow)
        } else {
            transcriptionWindow?.close()
        }
    }
}
