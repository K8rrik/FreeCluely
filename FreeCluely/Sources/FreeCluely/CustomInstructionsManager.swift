import Foundation

/// Менеджер для работы с кастомными инструкциями пользователя
class CustomInstructionsManager {
    static let shared = CustomInstructionsManager()
    
    private let userDefaultsKey = "userCustomInstructions"
    
    private init() {}
    
    /// Сохраняет кастомные инструкции пользователя
    func saveInstructions(_ instructions: String) {
        UserDefaults.standard.set(instructions, forKey: userDefaultsKey)
    }
    
    /// Загружает кастомные инструкции пользователя
    func loadInstructions() -> String {
        return UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
    }
    
    /// Очищает кастомные инструкции
    func clearInstructions() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    /// Базовый системный промпт (жестко закодированный)
    static let baseSystemPrompt = """
ВСЕГДА отвечай на русском языке.
Используй Markdown для форматирования.
Структурируй ответ заголовками.
Оформи вывод кода с использованием Markdown Code Blocks.
Обязательно указывай тег языка программирования (syntax highlighting tag) для каждого блока кода.
Не пиши комментарии и текст в блоках и между блоками кодов.
Не используй LaTeX. Пиши формулы обычным текстом.
Используй жирный шрифт для выделения.
Краткое объяснение, затем решение.
"""
    
    /// Создает полный системный промпт, объединяя базовый и пользовательский
    func buildFullSystemPrompt() -> String {
        let customInstructions = loadInstructions()
        
        if customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CustomInstructionsManager.baseSystemPrompt
        }
        
        return """
\(CustomInstructionsManager.baseSystemPrompt)

--- Дополнительные инструкции от пользователя ---
\(customInstructions)
"""
    }
}
