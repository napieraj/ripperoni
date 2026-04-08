// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macos-iokit-state",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "ripperoni-iokit-state", targets: ["ripperoni-iokit-state"]),
    ],
    targets: [
        .executableTarget(
            name: "ripperoni-iokit-state",
            path: "Sources"
        ),
    ]
)
