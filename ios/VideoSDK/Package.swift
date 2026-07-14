// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoSDK",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "VideoSDK",
            targets: ["VideoSDK"]
        ),
    ],
    targets: [
        .target(
            name: "VideoSDK",
            path: "Sources/VideoSDK"
        ),
    ]
)
