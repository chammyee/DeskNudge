// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Notipop",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Notipop",
            dependencies: [
                .product(name: "Lottie", package: "lottie-spm")
            ],
            path: "Sources/Notipop",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
