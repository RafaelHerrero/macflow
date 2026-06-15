import Foundation

/// Representação tipada do `config.toml` já validada.
///
/// Estrutura simples e imutável — fácil de passar entre módulos e testar.
struct Config: Sendable {

    /// Modificador usado para os atalhos de apps (ex.: Ctrl+1, Ctrl+2...).
    /// Padrão: apenas Control.
    let appModifier: String

    /// Mapeamento `tecla -> app`. A tecla normalmente é um dígito ("1".."9"),
    /// e o app pode ser um nome ("Safari") ou bundle id ("com.apple.Safari").
    let apps: [String: String]

    /// Mapeamento `ação de janela -> string de atalho` (ex.: "left" -> "Ctrl+Option+Left").
    let windows: [String: String]

    /// Configuração padrão usada quando o arquivo não existe ou está vazio.
    static let `default` = Config(
        appModifier: "Ctrl",
        apps: [:],
        windows: [:]
    )

    /// Constrói um `Config` a partir do documento TOML cru.
    static func from(document: TOMLParser.Document) -> Config {
        let settings = document["settings"] ?? [:]
        return Config(
            appModifier: settings["app_modifier"] ?? "Ctrl",
            apps: document["apps"] ?? [:],
            windows: document["windows"] ?? [:]
        )
    }
}
