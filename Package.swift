// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Gstrl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Gstrl",
            path: "Sources/Gstrl",
            resources: [
                .copy("Resources/whip.gif")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
