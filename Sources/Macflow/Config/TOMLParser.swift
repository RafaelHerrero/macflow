import Foundation

/// Minimal, dependency-free TOML parser.
///
/// Supports only the subset that Macflow needs, keeping the binary lightweight:
///   • Comments starting with `#` (including inline, outside of quotes).
///   • Section headers `[apps]`, `[windows]`, `[settings]`.
///   • `key = value` pairs, where the key can be bare (`left`) or quoted (`"1"`).
///   • String values quoted (`"Safari"`) or bare (`true`, `42`, `Ctrl+Left`).
///
/// The result is a simple structure: `[section: [key: value]]`.
/// Lines outside of any section are grouped under the empty key `""`.
enum TOMLParser {

    /// Parse result: dictionary of sections → (key → value).
    typealias Document = [String: [String: String]]

    /// Parses the TOML content. Individual syntax errors are ignored
    /// (the line is simply discarded) so a typo in the config never crashes the app.
    static func parse(_ content: String) -> Document {
        var document: Document = [:]
        var currentSection = ""

        for rawLine in content.components(separatedBy: .newlines) {
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            // Section header: [name]
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                currentSection = unquote(name)
                if document[currentSection] == nil { document[currentSection] = [:] }
                continue
            }

            // key = value pair
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = unquote(String(line[..<equals]).trimmingCharacters(in: .whitespaces))
            let value = unquote(String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces))
            guard !key.isEmpty else { continue }

            document[currentSection, default: [:]][key] = value
        }

        return document
    }

    // MARK: - Helpers

    /// Removes a `#...` comment from the line, respecting `#` inside quotes.
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

    /// Removes the outer double quotes, if present.
    private static func unquote(_ text: String) -> String {
        guard text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") else { return text }
        return String(text.dropFirst().dropLast())
    }
}
