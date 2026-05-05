// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TaigiTypeless",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TaigiTypeless", targets: ["TaigiTypeless"])
    ],
    targets: [
        .executableTarget(
            name: "TaigiTypeless",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "TaigiTypelessTests",
            dependencies: ["TaigiTypeless"]
        )
    ]
)
