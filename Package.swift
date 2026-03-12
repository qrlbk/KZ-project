// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MSProjectAnalog",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MSProjectAnalog", targets: ["MSProjectAnalog"]),
    ],
    targets: [
        .executableTarget(
            name: "MSProjectAnalog",
            path: "Sources/MSProjectAnalog",
            exclude: ["Info.plist"],
            resources: []
        ),
    ]
)
