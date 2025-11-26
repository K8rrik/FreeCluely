import Splash
import SwiftUI
import MarkdownUI

// MARK: - SwiftUI Color Extension
extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - MarkdownUI Theme
extension MarkdownUI.Theme {
    static var modernDark: MarkdownUI.Theme {
        MarkdownUI.Theme()
            .text {
                ForegroundColor(.white)
                FontSize(12)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.9))
                BackgroundColor(SwiftUI.Color(hex: "2d2d2d"))
                ForegroundColor(SwiftUI.Color(hex: "e0e0e0"))
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .relativeLineSpacing(.em(0.25))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.9))
                        }
                        .padding(16)
                }
                .background(SwiftUI.Color(hex: "1e1e1e"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(SwiftUI.Color(hex: "333333"), lineWidth: 1)
                )
                .padding(.bottom, 8)
            }
            .paragraph { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .padding(.bottom, 4)
            }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.3))
                    }
                    .padding(.bottom, 4)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.2))
                    }
                    .padding(.bottom, 4)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.1))
                    }
                    .padding(.bottom, 4)
            }
            .list { configuration in
                configuration.label
                    .padding(.bottom, 4)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(SwiftUI.Color(hex: "64B5F6"))
                        .frame(width: 4)
                    configuration.label
                        .padding()
                }
                .background(SwiftUI.Color(hex: "64B5F6").opacity(0.1))
                .cornerRadius(8)
                .fixedSize(horizontal: false, vertical: true)
            }
            .link {
                ForegroundColor(SwiftUI.Color(hex: "58a6ff"))
                UnderlineStyle(.single)
            }
    }
}

// MARK: - Splash Theme
extension Splash.Theme {
    static var customDracula: Splash.Theme {
        return Splash.Theme(
            font: .init(size: 14),
            plainTextColor: Splash.Color(hex: "e0e0e0"),
            tokenColors: [
                .keyword: Splash.Color(hex: "ff79c6"),
                .string: Splash.Color(hex: "f1fa8c"),
                .type: Splash.Color(hex: "8be9fd"),
                .call: Splash.Color(hex: "50fa7b"),
                .number: Splash.Color(hex: "bd93f9"),
                .comment: Splash.Color(hex: "6272a4"),
                .property: Splash.Color(hex: "f8f8f2"),
                .dotAccess: Splash.Color(hex: "f8f8f2"),
                .preprocessing: Splash.Color(hex: "ff79c6")
            ],
            backgroundColor: Splash.Color(hex: "1e1e1e") // Matches code block background
        )
    }

    static var gitHubDark: Splash.Theme {
        return Splash.Theme(
            font: .init(size: 14),
            plainTextColor: Splash.Color(hex: "c9d1d9"),
            tokenColors: [
                .keyword: Splash.Color(hex: "ff7b72"),
                .string: Splash.Color(hex: "a5d6ff"),
                .type: Splash.Color(hex: "79c0ff"),
                .call: Splash.Color(hex: "d2a8ff"),
                .number: Splash.Color(hex: "79c0ff"),
                .comment: Splash.Color(hex: "8b949e"),
                .property: Splash.Color(hex: "79c0ff"),
                .dotAccess: Splash.Color(hex: "c9d1d9"),
                .preprocessing: Splash.Color(hex: "ff7b72")
            ],
            backgroundColor: Splash.Color(hex: "1e1e1e")
        )
    }
}

// MARK: - Splash Color Extension
private extension Splash.Color {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
