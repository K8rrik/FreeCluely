import Foundation

enum GeminiModel: String, CaseIterable {
    case gemini3ProPreview = "gemini-3-pro-preview"
    case gemini25Pro = "gemini-2.5-pro"
    case gemini25Flash = "gemini-2.5-flash"
    
    var id: String { self.rawValue }
    
    var generationConfig: GenerationConfig {
        switch self {
        case .gemini3ProPreview:
            return GenerationConfig(
                maxOutputTokens: 65536,
                candidateCount: 1,
                thinkingConfig: ThinkingConfig(includeThoughts: true, thinkingLevel: "high")
            )
        case .gemini25Pro:
            return GenerationConfig(
                temperature: 0.7,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 8192,
                candidateCount: 1,
                thinkingConfig: nil
            )
        case .gemini25Flash:
            return GenerationConfig(
                temperature: 0.9,
                topP: 0.95,
                topK: 40,
                maxOutputTokens: 8192,
                candidateCount: 1,
                thinkingConfig: nil
            )
        default:
            return GenerationConfig(
                maxOutputTokens: 8192,
                candidateCount: 1,
                thinkingConfig: nil
            )
        }
    }
    var shortName: String {
        switch self {
        case .gemini3ProPreview:
            return "3.0 Pro"
        case .gemini25Pro:
            return "2.5 Pro"
        case .gemini25Flash:
            return "2.5 Flash"
        default:
            return "Gemini"
        }
    }
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
