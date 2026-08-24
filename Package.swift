// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpinPods",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpinPodsCore", targets: ["SpinPodsCore"]),
        .executable(name: "SpinPodsMac", targets: ["SpinPodsMac"]),
        .executable(name: "SpinPodsCoreChecks", targets: ["SpinPodsCoreChecks"])
    ],
    targets: [
        .target(name: "SpinPodsCore"),
        .executableTarget(
            name: "SpinPodsMac",
            dependencies: ["SpinPodsCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreMotion")
            ]
        ),
        .executableTarget(
            name: "SpinPodsCoreChecks",
            dependencies: ["SpinPodsCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
