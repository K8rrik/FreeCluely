import Foundation

struct DeepgramResponse: Codable {
    let metadata: DeepgramMetadata?
    let channel: DeepgramChannel?
    let is_final: Bool?
    let speech_final: Bool?
    
    enum CodingKeys: String, CodingKey {
        case metadata
        case channel
        case is_final
        case speech_final
    }
}

struct DeepgramMetadata: Codable {
    let request_id: String
    let model_info: DeepgramModelInfo?
    let model_uuid: String?
}

struct DeepgramModelInfo: Codable {
    let name: String
    let version: String
    let arch: String
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Double
    let words: [DeepgramWord]?
}

struct DeepgramWord: Codable {
    let word: String
    let start: Double
    let end: Double
    let confidence: Double
}
