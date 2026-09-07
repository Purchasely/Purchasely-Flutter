// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "purchasely_flutter",
    platforms: [
        .iOS("13.4")
    ],
    products: [
        .library(name: "purchasely-flutter", targets: ["purchasely_flutter"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/Purchasely/Purchasely-iOS.git",
            exact: "6.1.0"
        )
    ],
    targets: [
        .target(
            name: "purchasely_flutter",
            dependencies: [
                .product(name: "Purchasely", package: "Purchasely-iOS")
            ],
            path: "Classes",
            exclude: [
                "PurchaselyFlutterPlugin.h",
                "PurchaselyFlutterPlugin.m"
            ]
        )
    ]
)
