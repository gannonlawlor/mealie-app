// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "mealie-app",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .macCatalyst(.v17)],
    products: [
        .library(name: "MealieAppApp", type: .dynamic, targets: ["MealieApp"]),
        .library(name: "MealieUI", type: .dynamic, targets: ["MealieUI"]),
        .library(name: "MealieModel", type: .dynamic, targets: ["MealieModel"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.6.0"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.29.3"),
        .package(url: "https://source.skip.tools/skip-model.git", from: "1.5.0"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-fuse.git", from: "1.0.2"),
        .package(url: "https://source.skip.tools/skip-keychain.git", from: "0.3.0"),
    ],
    targets: [
        .target(name: "MealieApp", dependencies: [
            "MealieUI",
            .product(name: "SkipUI", package: "skip-ui"),
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),

        .target(name: "MealieUI", dependencies: [
            "MealieModel",
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),

        .target(name: "MealieModel", dependencies: [
            .product(name: "SkipFuse", package: "skip-fuse"),
            .product(name: "SkipModel", package: "skip-model"),
            .product(name: "SkipKeychain", package: "skip-keychain"),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),

        .testTarget(name: "MealieModelTests", dependencies: [
            "MealieModel",
            .product(name: "SkipTest", package: "skip"),
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
