// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OurWishCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OurWishCore",
            targets: ["OurWishCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        .target(
            name: "OurWishCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "OurWishCoreTests",
            dependencies: ["OurWishCore"]
        ),
        // Ad-hoc verification target: this machine only has Xcode Command Line Tools
        // installed (no Xcode.app), so neither XCTest nor swift-testing's `Testing`
        // module is available to run OurWishCoreTests via `swift test`. This plain
        // executable exercises the same core scenarios and can be run with
        // `swift run SmokeTest` on CLT alone. Once Xcode.app is installed, prefer
        // `swift test` / the Xcode test navigator and treat this as redundant.
        .executableTarget(
            name: "SmokeTest",
            dependencies: ["OurWishCore"]
        )
    ]
)
