// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeetingAlarm",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MeetingAlarm",
            path: "Sources/MeetingAlarm",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "MeetingAlarmTests",
            dependencies: ["MeetingAlarm"],
            path: "Tests/MeetingAlarmTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
