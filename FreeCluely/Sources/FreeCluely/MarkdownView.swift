import SwiftUI
import MarkdownUI
import Splash

struct MarkdownView: View {
    let text: String
    
    var body: some View {
        Markdown(text)
            .markdownTheme(.modernDark)
            .font(.system(size: 12, design: .rounded))
            .markdownCodeSyntaxHighlighter(HighlightrSyntaxHighlighter())
            .textSelection(.enabled)
            // Force dark mode for the markdown content since it's on a dark background
            .environment(\.colorScheme, .dark)
    }
}
