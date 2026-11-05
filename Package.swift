import PackageDescription

let package = Package(
    name: "FluxMarkdown",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.3"),
    ],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Markdown",
            sources: [
                "MarkdownApp.swift",
                "Common/",
                "LocalSchemeHandler.swift",
                "NotificationNames.swift",
                "ResourceLoader.swift",
                "WindowSizePersistence.swift",
            ]
        ),
        .target(
            name: "MarkdownPreview",
            path: "Sources/MarkdownPreview"
        ),
    ]
)
