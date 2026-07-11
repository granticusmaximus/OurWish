// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OurWishServer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OurWishServer",
            targets: ["OurWishServer"]
        )
    ],
    dependencies: [
        .package(path: "../OurWishCore"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "OurWishServer",
            dependencies: [
                .product(name: "OurWishCore", package: "OurWishCore"),
                .product(name: "Hummingbird", package: "hummingbird")
            ]
        ),
        .testTarget(
            name: "OurWishServerTests",
            dependencies: ["OurWishServer"]
        ),
        // Ad-hoc runner for command-line verification via `swift run RunServer` + `curl`,
        // mirroring OurWishCore's SmokeTest — lets the whole HTTP layer be validated
        // without Xcode.
        .executableTarget(
            name: "RunServer",
            dependencies: [
                "OurWishServer",
                .product(name: "OurWishCore", package: "OurWishCore")
            ]
        )
    ]
)
