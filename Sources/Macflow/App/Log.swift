import Foundation

/// Log mínimo para stderr. O LaunchAgent redireciona stderr para
/// /tmp/macflow.err.log, então é onde estas mensagens aparecem.
enum Log {
    static func info(_ message: String) {
        fputs("[macflow] \(message)\n", stderr)
    }
}
