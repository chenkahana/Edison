// swift-tools-version: 5.10
import PackageDescription

let targetExcludes = [
    "Tests",
    "AGENTS.md",
    "App/AGENTS.md",
    "Core/AGENTS.md",
    "Core/Capture/AGENTS.md",
    "Core/Clipboard/AGENTS.md",
    "Core/Models/AGENTS.md",
    "Core/Persistence/AGENTS.md",
    "Core/Search/AGENTS.md",
    "Core/Shortcuts/AGENTS.md",
    "Configs",
    "UI/AGENTS.md",
    "UI/Components/AGENTS.md",
    "UI/EditorUI/AGENTS.md",
    "UI/Hub/AGENTS.md"
]

let package = Package(
    name: "Edison",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Edison", targets: ["Edison"])
    ],
    targets: [
        .executableTarget(
            name: "Edison",
            path: "Edison",
            exclude: targetExcludes,
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EdisonTests",
            dependencies: ["Edison"],
            path: "Edison/Tests",
            exclude: ["AGENTS.md"]
        )
    ]
)
