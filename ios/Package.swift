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
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(name: "MealieApp", dependencies: [
            "MealieUI",
        ], resources: [.process("Resources")]),

        .target(name: "MealieUI", dependencies: [
            "MealieModel",
        ], resources: [.process("Resources")]),

        .target(name: "MealieModel"),

        .testTarget(name: "MealieModelTests", dependencies: [
            "MealieModel",
        ]),

        .testTarget(name: "MealieUISnapshotTests", dependencies: [
            "MealieUI",
            "MealieModel",
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        ]),
    ]
)
