// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Emergence",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "EmergenceCore",
            targets: ["EmergenceCore"]
        ),
        .executable(
            name: "EmergenceCLI",
            targets: ["EmergenceCLI"]
        )
    ],
    targets: [
        .target(
            name: "EmergenceCore",
            path: "EmergenceCore/Sources"
        ),
        .executableTarget(
            name: "EmergenceCLI",
            dependencies: ["EmergenceCore"],
            path: "CLI"
        ),
        .testTarget(
            name: "EmergenceTests",
            dependencies: ["EmergenceCore"],
            path: "Tests"
        )
    ]
)
