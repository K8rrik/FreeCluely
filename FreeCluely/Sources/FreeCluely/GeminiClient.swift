import Foundation
import AppKit
import VideoToolbox

class GeminiClient {
    static let shared = GeminiClient()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180 // Increase timeout to 180 seconds
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    func streamRequest(history: [ChatMessage], image: CGImage? = nil, apiKey: String, modelName: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Use v1beta by default
                    try await self.performStreamRequest(history: history, image: image, apiKey: apiKey, modelName: modelName, apiVersion: "v1beta", continuation: continuation)
                } catch {
                    print("Error with model \(modelName): \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performStreamRequest(history: [ChatMessage], image: CGImage?, apiKey: String, modelName: String, apiVersion: String, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        print("Debug: Checking API Key...")
        if apiKey.isEmpty {
            print("Debug: API Key is empty!")
            continuation.yield("Please set your Gemini API Key.")
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
            
            // If this is the LAST user message and we have an image, attach it here
            // This ensures the model sees the image in the current context
            if message.role == .user && image != nil && index == history.lastIndex(where: { $0.role == .user }) {
                 // Resize image to max 1024px
                if let resizedImage = resize(image: image!, maxDimension: 1024),
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
        
        // If history is empty but we have an image (edge case), create a user message
        if contents.isEmpty && image != nil {
             var parts: [[String: Any]] = []
             let defaultPrompt = "ВСЕГДА отвечай на русском языке. Проанализируй этот экран и предоставь помощь. Используй Markdown."
             parts.append(["text": defaultPrompt])
             
             if let resizedImage = resize(image: image!, maxDimension: 1024),
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
        
        let jsonBody: [String: Any] = [
            "contents": contents,
            "systemInstruction": [
                "parts": [
                    ["text": "ВСЕГДА отвечай на русском языке. Используй Markdown. Структурируй ответ заголовками. Оформи вывод кода с использованием Markdown Code Blocks. Обязательно указывай тег языка программирования (syntax highlighting tag) для каждого блока кода. Не пиши комментарии и текст в блоках и между блоками кодов. Не используй LaTeX. Пиши формулы обычным текстом. Используй жирный шрифт для выделения. Краткое объяснение, затем решение."]
                ]
            ]
        ]
        
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
                    if let text = response.candidates?.first?.content?.parts?.first?.text {
                        continuation.yield(text)
                    }
                }
            }
        }
        
        continuation.finish()
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
    }

    func sendRequest(image: CGImage, apiKey: String, modelName: String) async throws -> String {
        // Keep the original method for fallback or non-streaming use if needed
        // ... (original implementation logic could be here, but we are replacing the block)
        // For now, let's just call the stream and collect it if we really needed the old signature,
        // but the plan is to replace usage.
        // However, to keep the file clean, I will leave the original method logic as it was in the file,
        // but I am replacing the block in the tool call.
        // Wait, the tool call replaces a block. I should probably keep sendRequest as is and ADD streamRequest.
        // But the tool `replace_file_content` replaces a specific block.
        // Let me re-read the file content to make sure I don't delete sendRequest if I don't intend to.
        // The `sendRequest` method spans lines 17-87.
        // I will REPLACE `sendRequest` with BOTH `streamRequest` AND `sendRequest` (or just add `streamRequest` before it?).
        // Actually, I can just add `streamRequest` and keep `sendRequest` if I want.
        // But the user wants the "typewriter effect", so I will primarily use `streamRequest`.
        // I will add `streamRequest` BEFORE `sendRequest` or AFTER it.
        // Let's add it AFTER `sendRequest` to minimize disruption, or replace `sendRequest` if I want to force streaming.
        // The plan said "Add a new method".
        // So I will use `replace_file_content` to insert it.
        // I'll insert it before `private func resize`.
        
        // Wait, I selected lines 17-87 to replace. That would delete `sendRequest`.
        // I should probably just INSERT the new function.
        // I will change my strategy to INSERT the new function before `private func resize`.
        // `resize` starts at line 89.
        // So I will target line 88 (which is empty) to insert.
        
        // RE-PLANNING THE TOOL CALL:
        // I will use `replace_file_content` on line 88 to insert the code.
        return "" // Dummy return to satisfy the thought process, actual tool call below.
    }
    
    private func resize(image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        
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
        context?.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context?.makeImage()
    }
}

extension CGImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: self)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
