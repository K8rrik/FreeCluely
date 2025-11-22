import SwiftUI
import MarkdownUI
import Highlightr

struct HighlightrSyntaxHighlighter: CodeSyntaxHighlighter {
    private static let sharedHighlightr: Highlightr? = {
        let h = Highlightr()
        h?.setTheme(to: "atom-one-dark")
        return h
    }()
    
    init() {}
    
    func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlightr = Self.sharedHighlightr else {
            return Text(code)
        }
        
        // Highlightr returns NSAttributedString
        // If language is nil or empty, auto-detect
        let attributedString: NSAttributedString?
        if let language = language, !language.isEmpty {
            attributedString = highlightr.highlight(code, as: language)
        } else {
            attributedString = highlightr.highlight(code)
        }
        
        guard let attributed = attributedString else {
            return Text(code)
        }
        
        // Convert NSAttributedString to SwiftUI Text
        var text = Text("")
        
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attributes, range, _ in
            let substring = (attributed.string as NSString).substring(with: range)
            var textSegment = Text(substring)
            
            if let color = attributes[.foregroundColor] as? NSColor {
                textSegment = textSegment.foregroundColor(Color(nsColor: color))
            }
            
            // Apply font traits if possible (Bold/Italic)
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) {
                    textSegment = textSegment.bold()
                }
                if traits.contains(.italic) {
                    textSegment = textSegment.italic()
                }
            }
            
            text = text + textSegment
        }
        
        return text
    }
}
