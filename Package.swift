// swift-tools-version:6.0
import PackageDescription

// Macflow — global hotkey manager and window management for macOS.
//
// Deliberately built with NO external dependencies:
//   • Global hotkeys via Carbon (RegisterEventHotKey) — lightweight and reliable.
//   • Minimal in-house TOML parser (Sources/Macflow/Config/TOMLParser.swift).
//   • Window management via the Accessibility API (AXUIElement).
//
// Result: small binary, fast build, minimal CPU/RAM usage.
let package = Package(
    name: "Macflow",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Macflow",
            path: "Sources/Macflow",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
