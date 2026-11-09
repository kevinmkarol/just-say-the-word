// swift-tools-version:5.10
// ABOUTME: Just Say the Word: a menu-bar push-to-talk dictation app for the Mac (hold a key, speak, release, it pastes).
// ABOUTME: JustSayTheWordCore holds the testable logic; JustSayTheWord is the AppKit and SwiftUI shell around it.
import PackageDescription

let package = Package(
    name: "JustSayTheWord",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "JustSayTheWord", targets: ["JustSayTheWord"])],
    targets: [
        .target(name: "JustSayTheWordCore"),
        .executableTarget(name: "JustSayTheWord", dependencies: ["JustSayTheWordCore"]),
        .testTarget(name: "JustSayTheWordCoreTests", dependencies: ["JustSayTheWordCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
