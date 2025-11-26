import Foundation

struct ConfigLoader {
    static func loadEnv() -> [String: String] {
        // Priority 1: Current Directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        let envPath = currentDirectory + "/.env"
        
        var content = try? String(contentsOfFile: envPath, encoding: .utf8)
        
        // Priority 2: Bundle Resources
        if content == nil {
            if let bundlePath = Bundle.main.path(forResource: ".env", ofType: nil) {
                content = try? String(contentsOfFile: bundlePath, encoding: .utf8)
            }
        }
        
        guard let loadedContent = content else {
            print("Warning: .env file not found at \(envPath) or in Bundle Resources")
            return [:]
        }
        
        var env: [String: String] = [:]
        let lines = loadedContent.components(separatedBy: .newlines)
        
        for line in lines {
            let parts = line.split(separator: "=", maxSplits: 1).map { String($0) }
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                env[key] = value
            }
        }
        
        return env
    }
}
