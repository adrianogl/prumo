// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PRumoKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PRumoKit", targets: ["PRumoKit"])
    ],
    targets: [
        .target(name: "PRumoKit"),
        .testTarget(
            name: "PRumoKitTests",
            dependencies: ["PRumoKit"],
            resources: [.copy("Fixtures")]
        )
    ]
)
