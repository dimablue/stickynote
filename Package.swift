// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "StickyNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StickyNotes", targets: ["StickyNotes"])
    ],
    targets: [
        .executableTarget(
            name: "StickyNotes",
            path: "Sources/StickyNotes"
        ),
        .testTarget(
            name: "StickyNotesTests",
            dependencies: ["StickyNotes"],
            path: "Tests/StickyNotesTests"
        )
    ]
)
