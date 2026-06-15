import Foundation

/// Minimal logging to stderr. The LaunchAgent redirects stderr to
/// /tmp/macflow.err.log, so that's where these messages appear.
enum Log {
    static func info(_ message: String) {
        fputs("[macflow] \(message)\n", stderr)
    }
}
