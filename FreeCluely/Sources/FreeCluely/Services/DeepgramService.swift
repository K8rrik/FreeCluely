import Foundation
import Starscream

enum DeepgramError: Error {
    case connectionFailed
    case invalidResponse
}

struct TranscriptEvent {
    let text: String
    let isFinal: Bool
    let isSpeechFinal: Bool
}

class DeepgramService: ObservableObject {
    
    private var socket: WebSocket?
    private var isConnected = false
    private var apiKey: String?
    
    // Stream for publishing transcript events
    private var transcriptContinuation: AsyncStream<TranscriptEvent>.Continuation?
    lazy var transcriptStream: AsyncStream<TranscriptEvent> = {
        AsyncStream { continuation in
            self.transcriptContinuation = continuation
        }
    }()
    
    init() {}
    
    func connect(apiKey: String) {
        self.apiKey = apiKey
        
        // Deepgram Streaming URL
        // We use 'nova-2' model for speed and accuracy, and 'smart_format=true' for punctuation
        let urlString = "wss://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&encoding=linear16&sample_rate=48000&channels=1&language=ru"
        
        guard let url = URL(string: urlString) else {
            print("Invalid Deepgram URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
    }
    
    func sendAudioData(_ data: Data) {
        guard isConnected, let socket = socket else { return }
        socket.write(data: data)
    }
}

extension DeepgramService: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            isConnected = true
            print("Deepgram Connected: \(headers)")
            
        case .disconnected(let reason, let code):
            isConnected = false
            print("Deepgram Disconnected: \(reason) with code: \(code)")
            
        case .text(let string):
            handleResponse(string)
            
        case .binary(let data):
            // Deepgram usually sends text (JSON), but handle binary just in case
            if let string = String(data: data, encoding: .utf8) {
                handleResponse(string)
            }
            
        case .ping, .pong:
            break
            
        case .viabilityChanged, .reconnectSuggested:
            break
            
        case .cancelled:
            isConnected = false
            
        case .error(let error):
            isConnected = false
            print("Deepgram Error: \(String(describing: error))")
            
        case .peerClosed:
            isConnected = false
            print("Deepgram Peer Closed")
        }
    }
    
    private func handleResponse(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            
            if let alternative = response.channel?.alternatives.first, !alternative.transcript.isEmpty {
                let event = TranscriptEvent(
                    text: alternative.transcript,
                    isFinal: response.is_final ?? false,
                    isSpeechFinal: response.speech_final ?? false
                )
                transcriptContinuation?.yield(event)
            }
        } catch {
            print("Failed to decode Deepgram response: \(error)")
        }
    }
}
