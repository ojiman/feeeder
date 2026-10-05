// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RSSReader",
    platforms: [.macOS("26.6")],
    products: [.executable(name: "RSSReader", targets: ["RSSReader"])],
    dependencies: [.package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.13.9")],
    targets: [
        .target(name: "ReaderCore", dependencies: ["SwiftSoup"]),
        .executableTarget(name: "RSSReader", dependencies: ["ReaderCore"]),
        .testTarget(name: "ReaderCoreTests", dependencies: ["ReaderCore"]),
        .testTarget(name: "ReaderUITests", dependencies: ["RSSReader"])
    ]
)
