// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FreeCluely",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "FreeCluely",
            targets: ["FreeCluely"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/MarkdownUI", from: "2.1.0"),
        .package(url: "https://github.com/johnsundell/splash", from: "0.16.0"),
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "FreeCluely",
            dependencies: [
                .product(name: "MarkdownUI", package: "MarkdownUI"),
                .product(name: "Splash", package: "Splash"),
                .product(name: "Highlightr", package: "Highlightr")
            ]),
    ]
)
