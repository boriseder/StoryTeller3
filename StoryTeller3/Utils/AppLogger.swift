import os
import Foundation

enum AppLogger {
    private static let subsystem = "com.meinefirma.StoryTeller3"

    struct LogWrapper {
        let logger: Logger
        let category: String

        func write(_ level: String, message: String, osLevel: OSLogType) {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let line = "[\(timestamp)] \(level) [\(category)] \(message)"

            #if DEBUG
            print(line)
            #endif

            AppLogger.writeToFile(line)
            logger.log(level: osLevel, "\(message, privacy: .public)")
        }

        func debug(_ msg: String) { write("🐞 DEBUG", message: msg, osLevel: .debug) }
        func info(_ msg: String)  { write("ℹ️ INFO", message: msg, osLevel: .info) }
        func warn(_ msg: String)  { write("⚠️ WARN", message: msg, osLevel: .default) }
        func error(_ msg: String) { write("❌ ERROR", message: msg, osLevel: .error) }
    }

    // Kategorien
    static let general = LogWrapper(logger: Logger(subsystem: subsystem, category: "General"), category: "General")
    static let ui      = LogWrapper(logger: Logger(subsystem: subsystem, category: "UI"), category: "UI")
    static let network = LogWrapper(logger: Logger(subsystem: subsystem, category: "Network"), category: "Network")
    static let audio   = LogWrapper(logger: Logger(subsystem: subsystem, category: "Audio"), category: "Audio")
    static let cache   = LogWrapper(logger: Logger(subsystem: subsystem, category: "Cache"), category: "Cache")

    // MARK: - Datei-Logging
    private static let logFileURL: URL = {
        let fm = FileManager.default
        let url = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppLogs.txt")
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        return url
    }()

    static func writeToFile(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }

    static func logFilePath() -> URL { logFileURL }
}
