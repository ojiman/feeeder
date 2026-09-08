// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RSSReader",
    platforms: [.macOS("26.6")],
    products: [.executable(name: "RSSReader", targets: ["RSSReader"])],
    targets: [
        .target(name: "ReaderCore"),
        .executableTarget(name: "RSSReader", dependencies: ["ReaderCore"]),
        .testTarget(name: "ReaderCoreTests", dependencies: ["ReaderCore"])
    ]
)
