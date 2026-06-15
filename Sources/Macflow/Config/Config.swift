import Foundation

/// Typed, already-validated representation of `config.toml`.
///
/// Simple and immutable structure — easy to pass between modules and to test.
struct Config: Sendable {

    /// Modifier used for app shortcuts (e.g. Ctrl+1, Ctrl+2...).
    /// Default: Control only.
    let appModifier: String

    /// `key -> app` mapping. The key is usually a digit ("1".."9"),
    /// and the app can be a name ("Safari") or a bundle id ("com.apple.Safari").
    let apps: [String: String]

    /// `window action -> shortcut string` mapping (e.g. "left" -> "Ctrl+Option+Left").
    let windows: [String: String]

    /// Default configuration used when the file does not exist or is empty.
    static let `default` = Config(
        appModifier: "Ctrl",
        apps: [:],
        windows: [:]
    )

    /// Builds a `Config` from the raw TOML document.
    static func from(document: TOMLParser.Document) -> Config {
        let settings = document["settings"] ?? [:]
        return Config(
            appModifier: settings["app_modifier"] ?? "Ctrl",
            apps: document["apps"] ?? [:],
            windows: document["windows"] ?? [:]
        )
    }
}
