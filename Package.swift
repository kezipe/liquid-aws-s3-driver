// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "liquid-aws-s3-driver",
    platforms: [
       .iOS(.v13),
       .macOS(.v12),
    ],
    products: [
        .library(name: "LiquidAWSS3Driver", targets: ["LiquidAWSS3Driver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/aoenth/liquid-kit.git", from: "1.3.6"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.7.62"),
    ],
    targets: [
        .target(name: "LiquidAWSS3Driver", dependencies: [
            .product(name: "LiquidKit", package: "liquid-kit"),
            .product(name: "AWSS3", package: "aws-sdk-swift"),
        ]),
        .testTarget(name: "LiquidAWSS3DriverTests", dependencies: [
            .target(name: "LiquidAWSS3Driver"),
        ]),
    ]
)
