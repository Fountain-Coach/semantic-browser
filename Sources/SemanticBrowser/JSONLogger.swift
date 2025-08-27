import Foundation

enum LogLevel: String { case debug, info, warn, error }

func logJSON(_ level: LogLevel, _ message: String, _ fields: [String: Any] = [:]) {
    var base: [String: Any] = [
        "ts": ISO8601DateFormatter().string(from: Date()),
        "level": level.rawValue,
        "msg": message
    ]
    for (k, v) in fields { base[k] = v }
    if let data = try? JSONSerialization.data(withJSONObject: base), let line = String(data: data, encoding: .utf8) {
        print(line)
    }
}

