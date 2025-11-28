import Foundation

enum MessageRole: String, Codable {
    case user
    case ai
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    var text: String
    var thought: String?
    let timestamp: Date
    var imageData: Data?
    var isAmbient: Bool = false
    
    init(id: UUID = UUID(), role: MessageRole, text: String, thought: String? = nil, timestamp: Date = Date(), imageData: Data? = nil, isAmbient: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.thought = thought
        self.timestamp = timestamp
        self.imageData = imageData
        self.isAmbient = isAmbient
    }
}

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var messages: [ChatMessage]
    let timestamp: Date
    
    init(id: UUID = UUID(), messages: [ChatMessage] = [], timestamp: Date = Date()) {
        self.id = id
        self.messages = messages
        self.timestamp = timestamp
    }
}

class HistoryManager {
    static let shared = HistoryManager()
    
    private let fileName = "chat_history.json" // Changed filename to avoid conflict/migration issues for now
    
    private var fileURL: URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDirectory = documentsDirectory.appendingPathComponent("FreeCluely")
        
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory.appendingPathComponent(fileName)
    }
    
    func saveHistory(_ sessions: [ChatSession]) {
        guard let url = fileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: url)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    func loadHistory() -> [ChatSession] {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let sessions = try JSONDecoder().decode([ChatSession].self, from: data)
            return sessions.sorted(by: { $0.timestamp > $1.timestamp })
        } catch {
            print("Failed to load history: \(error)")
            return []
        }
    }
}
