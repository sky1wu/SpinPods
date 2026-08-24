// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpinPod",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpinPodCore", targets: ["SpinPodCore"]),
        .executable(name: "SpinPodMac", targets: ["SpinPodMac"]),
        .executable(name: "SpinPodCoreChecks", targets: ["SpinPodCoreChecks"])
    ],
    targets: [
        .target(name: "SpinPodCore"),
        .executableTarget(
            name: "SpinPodMac",
            dependencies: ["SpinPodCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreMotion")
            ]
        ),
        .executableTarget(
            name: "SpinPodCoreChecks",
            dependencies: ["SpinPodCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
