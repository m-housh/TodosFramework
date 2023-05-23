// swift-tools-version: 5.8

import PackageDescription

let package = Package(
  name: "TodosFramework",
  platforms: [
    .iOS(.v16),
    .macOS(.v13)
  ],
  products: [
    .library(name: "SharedModels", targets: ["SharedModels"]),
    .library(name: "TodoClient", targets: ["TodoClient"]),
    .library(name: "TodoClientLive", targets: ["TodoClientLive"]),
    .library(name: "TodoFeature", targets: ["TodoFeature"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies.git",
      from: "0.5.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture.git",
      branch: "prerelease/1.0"
    ),
    .package(
      url: "https://github.com/tgrapperon/swift-dependencies-additions.git",
      from: "0.5.1"
    )
  ],
  targets: [
    .target(
      name: "SharedModels",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      resources: [
        .copy("Resources/Model")
      ]
    ),
    .testTarget(
      name: "TodosFrameworkTests",
      dependencies: ["SharedModels"]
    ),
    .target(
      name: "TodoClient",
      dependencies: [
        "SharedModels",
        .product(name: "Dependencies", package: "swift-dependencies")
      ]
    ),
    .target(
      name: "TodoClientLive",
      dependencies: [
        "SharedModels",
        "TodoClient",
        .product(name: "DependenciesAdditions", package: "swift-dependencies-additions")
      ]
    ),
    .target(
      name: "TodoFeature",
      dependencies: [
        "TodoClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
      ]
    )
  ]
)
