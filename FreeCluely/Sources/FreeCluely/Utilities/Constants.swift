import Foundation

struct AppConstants {
    static let appName = "FreeCluely"
    
    struct UI {
        static let cornerRadius: CGFloat = 20
        static let messageCornerRadius: CGFloat = 12
        static let buttonSize: CGFloat = 20
        static let buttonPadding: CGFloat = 6
    }
    
    struct Gemini {
        static let defaultModel = "gemini-3-pro-preview"
        static let maxOutputTokens = 65536
        static let apiVersion = "v1beta"
        static let baseUrl = "https://generativelanguage.googleapis.com"
    }
    
    struct Placeholders {
        static let loading = "Please wait, generating..."
        static let inputDefault = "Analyze Screen (⌘⇧A) or Ask anything..."
    }
    
    struct ErrorMessages {
        static let noApiKey = "Please set your Gemini API Key."
        static let invalidUrl = "Invalid URL"
        static let invalidResponse = "Invalid Response"
    }
}
