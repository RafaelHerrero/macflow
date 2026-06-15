import Foundation

/// Parser TOML mínimo e dependency-free.
///
/// Suporta apenas o subconjunto que o Macflow precisa, mantendo o binário leve:
///   • Comentários iniciados por `#` (inclusive inline, fora de aspas).
///   • Cabeçalhos de seção `[apps]`, `[windows]`, `[settings]`.
///   • Pares `chave = valor`, com chave podendo ser nua (`left`) ou entre aspas (`"1"`).
///   • Valores string entre aspas (`"Safari"`) ou nus (`true`, `42`, `Ctrl+Left`).
///
/// O resultado é uma estrutura simples: `[seção: [chave: valor]]`.
/// Linhas fora de qualquer seção são agrupadas sob a chave vazia `""`.
enum TOMLParser {

    /// Resultado do parse: dicionário de seções → (chave → valor).
    typealias Document = [String: [String: String]]

    /// Faz o parse do conteúdo TOML. Erros de sintaxe individuais são ignorados
    /// (linha simplesmente descartada) para nunca derrubar o app por um typo no config.
    static func parse(_ content: String) -> Document {
        var document: Document = [:]
        var currentSection = ""

        for rawLine in content.components(separatedBy: .newlines) {
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Cabeçalho de seção: [nome]
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                currentSection = unquote(name)
                if document[currentSection] == nil { document[currentSection] = [:] }
                continue
            }

            // Par chave = valor
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = unquote(String(line[..<equals]).trimmingCharacters(in: .whitespaces))
            let value = unquote(String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces))
            guard !key.isEmpty else { continue }

            document[currentSection, default: [:]][key] = value
        }

        return document
    }

    // MARK: - Helpers

    /// Remove um comentário `#...` da linha, respeitando `#` dentro de aspas.
    private static func stripComment(from line: String) -> String {
        var insideQuotes = false
        var result = ""
        for char in line {
            if char == "\"" { insideQuotes.toggle() }
            if char == "#" && !insideQuotes { break }
            result.append(char)
        }
        return result
    }

    /// Remove aspas duplas externas, se presentes.
    private static func unquote(_ text: String) -> String {
        guard text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") else { return text }
        return String(text.dropFirst().dropLast())
    }
}
