// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MQTTDecoder",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "NIOMQTTServer",
            targets: ["NIOMQTTServer"]),
        .executable(
            name: "NIOMQTTClient",
            targets: ["NIOMQTTClient"]),
        .library(
            name: "MQTTDecoder",
            targets: ["MQTTDecoder"]),

    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.8.0"),
//        .package(url: "https://github.com/ReactiveX/RxSwift.git", "4.0.0" ..< "5.0.0")
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MQTTDecoder",
            dependencies: ["NIO"]),
        .target(
            name: "NIOMQTTServer",
            dependencies: ["NIO", "MQTTDecoder"],
            path: "NIOMQTTServer"),
        .target(
            name: "NIOMQTTClient",
            dependencies: ["NIO", "MQTTDecoder"],
            path: "NIOMQTTClient"),
        .testTarget(
            name: "MQTTDecoderTests",
            dependencies: ["MQTTDecoder"]),
    ]
)
