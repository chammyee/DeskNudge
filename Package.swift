// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeskNudge",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0")
    ],
    targets: [
        .executableTarget(
            name: "DeskNudge",
            dependencies: [
                .product(name: "Lottie", package: "lottie-spm")
            ],
            path: "Sources/DeskNudge",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
