import PackageDescription

let package = Package(
    name: "FluxMarkdown",
    platforms: [.macOS(.v11)],
    dependencies: [],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [],
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
