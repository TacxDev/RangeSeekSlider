// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "RangeSeekSlider",
    platforms: [.iOS(.v14)],
    products: [.library(name: "RangeSeekSlider", targets: ["RangeSeekSlider"])],
    targets: [.target(name: "RangeSeekSlider")]
)
