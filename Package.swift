// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iGest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "iGest",
            path: "Sources/iGest",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "iGestTests",
            dependencies: ["iGest"],
            path: "Tests/iGestTests"
        )
    ]
)
