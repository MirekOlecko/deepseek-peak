// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepSeekPeak",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DeepSeekPeak", targets: ["DeepSeekPeak"])
    ],
    targets: [
        .target(name: "DeepSeekPeakCore", path: "Sources/DeepSeekPeakCore"),
        .executableTarget(
            name: "DeepSeekPeak",
            dependencies: ["DeepSeekPeakCore"],
            path: "Sources/DeepSeekPeak"
        ),
        .testTarget(
            name: "DeepSeekPeakCoreTests",
            dependencies: ["DeepSeekPeakCore"],
            path: "Tests/DeepSeekPeakCoreTests"
        )
    ]
)
