// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ScrollFix",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ScrollFix",
            path: "Sources/ScrollFix"
        )
    ]
)
