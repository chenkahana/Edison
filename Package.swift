// swift-tools-version: 5.10
import PackageDescription

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
            exclude: ["Tests"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EdisonTests",
            dependencies: ["Edison"],
            path: "Edison/Tests"
        )
    ]
)
