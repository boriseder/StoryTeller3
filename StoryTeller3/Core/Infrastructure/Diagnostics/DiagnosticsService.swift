import Foundation
import UIKit

protocol DiagnosticsCollecting {
    func collectDebugLogs() -> String?
    func exportLogs(completion: @escaping (URL?) -> Void)
}

class DiagnosticsService: DiagnosticsCollecting {
    
    private let storageMonitor: StorageMonitoring
    
    init(storageMonitor: StorageMonitoring = StorageMonitor()) {
        self.storageMonitor = storageMonitor
    }
    
    func collectDebugLogs() -> String? {
        let storageInfo = storageMonitor.getStorageInfo()
        
        var logContent = """
        StoryTeller Debug Logs
        Generated: \(Date().ISO8601Format())
        
        === System Information ===
        App Version: \(getAppVersion())
        Build: \(getBuildNumber())
        iOS Version: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        
        === Storage Information ===
        Total Space: \(storageInfo.totalSpaceFormatted)
        Available Space: \(storageInfo.availableSpaceFormatted)
        Used Space: \(storageInfo.usedSpaceFormatted)
        Used Percentage: \(String(format: "%.1f%%", storageInfo.usedPercentage * 100))
        
        === App Settings ===
        """
        
        let defaults = UserDefaults.standard
        
        if let serverHost = defaults.string(forKey: "server_host") {
            logContent += "\nServer Host: \(serverHost)"
        }
        
        if let serverScheme = defaults.string(forKey: "server_scheme") {
            logContent += "\nServer Scheme: \(serverScheme)"
        }
        
        if let username = defaults.string(forKey: "stored_username") {
            logContent += "\nUsername: \(username)"
        }
        
        logContent += "\nConnection Timeout: \(defaults.double(forKey: "connection_timeout"))s"
        logContent += "\nMax Concurrent Downloads: \(defaults.integer(forKey: "max_concurrent_downloads"))"
        logContent += "\nCover Cache Limit: \(defaults.integer(forKey: "cover_cache_limit"))"
        logContent += "\nMemory Cache Size: \(defaults.integer(forKey: "memory_cache_size")) MB"
        logContent += "\nDebug Logging: \(defaults.bool(forKey: "enable_debug_logging"))"
        
        logContent += "\n\n=== End of Debug Log ===\n"
        
        return logContent
    }
    
    func exportLogs(completion: @escaping (URL?) -> Void) {
        guard let logData = collectDebugLogs() else {
            completion(nil)
            return
        }
        
        let fileName = "StoryTeller-Debug-\(Date().ISO8601Format()).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try logData.write(to: tempURL, atomically: true, encoding: .utf8)
            completion(tempURL)
        } catch {
            AppLogger.general.debug("[Diagnostics] Failed to export logs: \(error)")
            completion(nil)
        }
    }
    
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
