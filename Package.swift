// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PIU",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PIU",
            path: "Sources/PIU"
        )
    ]
)
