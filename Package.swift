// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PriceAdjustPro",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2")
    ]
) 