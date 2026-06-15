// swift-tools-version:6.0
import PackageDescription

// Macflow — gerenciador de atalhos globais e window management para macOS.
//
// Projeto deliberadamente SEM dependências externas:
//   • Hotkeys globais via Carbon (RegisterEventHotKey) — leve e confiável.
//   • Parser TOML mínimo próprio (Sources/Macflow/Config/TOMLParser.swift).
//   • Window management via Accessibility API (AXUIElement).
//
// Resultado: binário pequeno, build rápido, consumo de CPU/RAM mínimo.
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
