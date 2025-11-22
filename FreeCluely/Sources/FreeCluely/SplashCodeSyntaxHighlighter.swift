import SwiftUI
import MarkdownUI
import Splash
import Foundation

struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let syntaxHighlighter: SyntaxHighlighter<AttributedStringOutputFormat>

    init(theme: Splash.Theme) {
        self.syntaxHighlighter = SyntaxHighlighter(format: AttributedStringOutputFormat(theme: theme))
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        guard language != nil else {
            return Text(code)
        }
        
        let highlighted = syntaxHighlighter.highlight(code)
        var attributedString = AttributedString(highlighted)
        
        // Custom comment highlighting for # and //
        let pattern = #"^\s*(#|//).*$"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)
            let matches = regex.matches(in: code, options: [], range: NSRange(location: 0, length: code.utf16.count))
            
            for match in matches {
                if let range = Range(match.range, in: attributedString) {
                    attributedString[range].foregroundColor = .gray
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return Text(attributedString)
    }
}

extension CodeSyntaxHighlighter where Self == SplashCodeSyntaxHighlighter {
    static func splash(theme: Splash.Theme) -> Self {
        SplashCodeSyntaxHighlighter(theme: theme)
    }
}
