import Foundation
import AppKit
import VideoToolbox

// MARK: - Configuration Models

enum GeminiModel: String, CaseIterable {
    case gemini3ProPreview = "gemini-3-pro-preview"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"
    case geminiPro = "gemini-pro"
    
    var id: String { self.rawValue }
}

struct GenerationConfig: Encodable {
    var temperature: Float?
    var topP: Float?
    var topK: Int?
    var maxOutputTokens: Int?
    var stopSequences: [String]?
    var candidateCount: Int?
    var thinkingConfig: ThinkingConfig?
    
    init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil, maxOutputTokens: Int? = nil, stopSequences: [String]? = nil, candidateCount: Int? = nil, thinkingConfig: ThinkingConfig? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxOutputTokens = maxOutputTokens
        self.stopSequences = stopSequences
        self.candidateCount = candidateCount
        self.thinkingConfig = thinkingConfig
    }
}

struct ThinkingConfig: Encodable {
    var includeThoughts: Bool?
    var thinkingLevel: String? // "low", "high"
    
    init(includeThoughts: Bool? = nil, thinkingLevel: String? = nil) {
        self.includeThoughts = includeThoughts
        self.thinkingLevel = thinkingLevel
    }
}

struct Tool: Encodable {
    var googleSearch: GoogleSearch?
    
    struct GoogleSearch: Encodable {}
    
    init(googleSearch: Bool = false) {
        if googleSearch {
            self.googleSearch = GoogleSearch()
        }
    }
}

enum SafetyCategory: String, Encodable {
    case harassment = "HARM_CATEGORY_HARASSMENT"
    case hateSpeech = "HARM_CATEGORY_HATE_SPEECH"
    case sexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    case dangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
}

enum SafetyThreshold: String, Encodable {
    case blockNone = "BLOCK_NONE"
    case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
    case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
    case blockOnlyHigh = "BLOCK_ONLY_HIGH"
    case blockUnspecified = "HARM_BLOCK_THRESHOLD_UNSPECIFIED"
}

struct SafetySetting: Encodable {
    let category: SafetyCategory
    let threshold: SafetyThreshold
}

struct GeminiError: Error, Decodable, LocalizedError {
    let error: ErrorDetail
    
    struct ErrorDetail: Decodable {
        let code: Int
        let message: String
        let status: String
    }
    
    var errorDescription: String? {
        return "Gemini API Error (\(error.code)): \(error.message)"
    }
}

// MARK: - Client

class GeminiClient {
    static let shared = GeminiClient()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 360 // Increase timeout to 360 seconds (6 minutes)
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    /// Streams the response from Gemini API
    /// - Parameters:
    ///   - history: Chat history
    ///   - image: Optional image for multimodal requests
    ///   - apiKey: The API Key
    ///   - model: The model to use (enum)
    ///   - systemInstruction: Optional system instruction to override default
    ///   - generationConfig: Optional generation parameters
    ///   - safetySettings: Optional safety settings
    ///   - tools: Optional tools (e.g. Google Search)
    func streamRequest(
        history: [ChatMessage],
        image: CGImage? = nil,
        apiKey: String,
        model: GeminiModel,
        systemInstruction: String? = nil,
        generationConfig: GenerationConfig? = nil,
        safetySettings: [SafetySetting]? = nil,
        tools: [Tool]? = nil
    ) -> AsyncThrowingStream<StreamUpdate, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.performStreamRequest(
                        history: history,
                        image: image,
                        apiKey: apiKey,
                        modelName: model.rawValue,
                        apiVersion: "v1beta",
                        systemInstruction: systemInstruction,
                        generationConfig: generationConfig,
                        safetySettings: safetySettings,
                        tools: tools,
                        continuation: continuation
                    )
                } catch {
                    print("Error with model \(model.rawValue): \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // Legacy support if needed, but prefer using the enum version
    // Updated to accept String model name but map it if possible, or just pass through
    func streamRequest(history: [ChatMessage], image: CGImage? = nil, apiKey: String, modelName: String) -> AsyncThrowingStream<StreamUpdate, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.performStreamRequest(
                        history: history,
                        image: image,
                        apiKey: apiKey,
                        modelName: modelName,
                        apiVersion: "v1beta",
                        systemInstruction: nil,
                        generationConfig: nil,
                        safetySettings: nil,
                        tools: nil,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performStreamRequest(
        history: [ChatMessage],
        image: CGImage?,
        apiKey: String,
        modelName: String,
        apiVersion: String,
        systemInstruction: String?,
        generationConfig: GenerationConfig?,
        safetySettings: [SafetySetting]?,
        tools: [Tool]?,
        continuation: AsyncThrowingStream<StreamUpdate, Error>.Continuation
    ) async throws {
        print("Debug: Checking API Key...")
        if apiKey.isEmpty {
            print("Debug: API Key is empty!")
            continuation.yield(StreamUpdate(text: "Please set your Gemini API Key.", thought: nil))
            continuation.finish()
            return
        }
        
        let urlString = "https://generativelanguage.googleapis.com/\(apiVersion)/models/\(modelName):streamGenerateContent?key=\(apiKey)&alt=sse"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var contents: [[String: Any]] = []
        
        // Convert history to API format
        for (index, message) in history.enumerated() {
            var parts: [[String: Any]] = []
            
            // Add text
            parts.append(["text": message.text])
            
            // Check for image data in the message
            if let imageData = message.imageData {
                let base64Image = imageData.base64EncodedString()
                parts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": base64Image
                    ]
                ])
            }
            // Fallback: If this is the LAST user message and we have an image argument (legacy/direct call), attach it here
            else if message.role == .user && image != nil && index == history.lastIndex(where: { $0.role == .user }) {
                 // Resize image to max 1024px
                if let resizedImage = image?.resize(maxDimension: 1024),
                   let imageData = resizedImage.jpegData(compressionQuality: 0.7) {
                    let base64Image = imageData.base64EncodedString()
                    parts.append([
                        "inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]
                    ])
                }
            }
            
            let role = message.role == .user ? "user" : "model"
            contents.append([
                "role": role,
                "parts": parts
            ])
        }
        
        // Edge case: Empty history but image present
        if contents.isEmpty && image != nil {
             var parts: [[String: Any]] = []
             let defaultPrompt = "ВСЕГДА отвечай на русском языке. Проанализируй этот экран и предоставь помощь. Используй Markdown."
             parts.append(["text": defaultPrompt])
             
             if let resizedImage = image?.resize(maxDimension: 1024),
                let imageData = resizedImage.jpegData(compressionQuality: 0.7) {
                 let base64Image = imageData.base64EncodedString()
                 parts.append([
                     "inline_data": [
                         "mime_type": "image/jpeg",
                         "data": base64Image
                     ]
                 ])
             }
             contents.append([
                "role": "user",
                "parts": parts
             ])
        }
        
        let defaultSystemPrompt = CustomInstructionsManager.shared.buildFullSystemPrompt()
        
        let finalSystemInstruction = systemInstruction ?? defaultSystemPrompt
        
        var jsonBody: [String: Any] = [
            "contents": contents,
            "systemInstruction": [
                "parts": [
                    ["text": finalSystemInstruction]
                ]
            ]
        ]
        
        if let config = generationConfig {
            var configDict: [String: Any] = [:]
            if let temp = config.temperature { configDict["temperature"] = temp }
            if let topP = config.topP { configDict["topP"] = topP }
            if let topK = config.topK { configDict["topK"] = topK }
            if let maxTokens = config.maxOutputTokens { configDict["maxOutputTokens"] = maxTokens }
            if let stops = config.stopSequences { configDict["stopSequences"] = stops }
            if let count = config.candidateCount { configDict["candidateCount"] = count }
            
            if let thinking = config.thinkingConfig {
                var thinkingDict: [String: Any] = [:]
                if let include = thinking.includeThoughts { thinkingDict["includeThoughts"] = include }
                if let level = thinking.thinkingLevel { thinkingDict["thinkingLevel"] = level }
                if !thinkingDict.isEmpty {
                    configDict["thinkingConfig"] = thinkingDict
                }
            }
            
            if !configDict.isEmpty {
                jsonBody["generationConfig"] = configDict
            }
        }
        
        if let safety = safetySettings {
            let safetyDicts = safety.map { setting -> [String: String] in
                return [
                    "category": setting.category.rawValue,
                    "threshold": setting.threshold.rawValue
                ]
            }
            if !safetyDicts.isEmpty {
                jsonBody["safetySettings"] = safetyDicts
            }
        }
        
        if let toolsList = tools {
            let toolsDicts = toolsList.map { tool -> [String: Any] in
                var dict: [String: Any] = [:]
                if tool.googleSearch != nil {
                    dict["googleSearch"] = [:] as [String: Any]
                }
                return dict
            }
            if !toolsDicts.isEmpty {
                jsonBody["tools"] = toolsDicts
            }
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonBody)
        request.httpBody = jsonData
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid Response", code: -1, userInfo: nil)
        }
        
        if httpResponse.statusCode != 200 {
            var errorText = ""
            for try await line in bytes.lines {
                errorText += line + "\n"
            }
            print("API Error Body: \(errorText)")
            
            // Try to decode GeminiError
            if let data = errorText.data(using: .utf8),
               let geminiError = try? JSONDecoder().decode(GeminiError.self, from: data) {
                throw geminiError
            }
            
            // Fallback
            let errorMessage = "API Error (\(httpResponse.statusCode)): \(errorText.trimmingCharacters(in: .whitespacesAndNewlines))"
            let userInfo = [NSLocalizedDescriptionKey: errorMessage]
            throw NSError(domain: "GeminiClient", code: httpResponse.statusCode, userInfo: userInfo)
        }
        
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" { break }
                
                if let data = jsonString.data(using: .utf8),
                   let response = try? JSONDecoder().decode(StreamResponse.self, from: data) {
                    if let part = response.candidates?.first?.content?.parts?.first {
                        if let isThought = part.thought, isThought {
                            continuation.yield(StreamUpdate(text: nil, thought: part.text))
                        } else {
                            continuation.yield(StreamUpdate(text: part.text, thought: nil))
                        }
                    }
                }
            }
        }
        
        continuation.finish()
    }

    struct StreamUpdate {
        let text: String?
        let thought: String?
    }

    // Helper structs for decoding streaming response
    struct StreamResponse: Decodable {
        let candidates: [Candidate]?
    }

    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
        let thought: Bool?
    }
    
    // resize method moved to CGImage extension
}

extension CGImage {
    func resize(maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(self.width)
        let height = CGFloat(self.height)
        
        let aspectRatio = width / height
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if width > height {
            newWidth = min(width, maxDimension)
            newHeight = newWidth / aspectRatio
        } else {
            newHeight = min(height, maxDimension)
            newWidth = newHeight * aspectRatio
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: Int(newWidth),
            height: Int(newHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.interpolationQuality = .high
        context?.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context?.makeImage()
    }
}

extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
