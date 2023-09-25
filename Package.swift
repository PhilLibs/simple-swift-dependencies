// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "Dependencies",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "Dependencies",
            targets: ["Dependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Dependencies",
            dependencies: [
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay")
            ]
        ),
        .testTarget(
            name: "DependenciesTests",
            dependencies: ["Dependencies"]),
    ]
)

#if !os(Windows)
  // Add the documentation compiler plugin if possible
  package.dependencies.append(
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
  )
#endif
