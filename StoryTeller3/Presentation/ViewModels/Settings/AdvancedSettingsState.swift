import Foundation

struct AdvancedSettingsState {
    var connectionTimeout: Double = 30
    var maxConcurrentDownloads: Int = 3
    var coverCacheLimit: Int = 100
    var memoryCacheSize: Int = 50
    var enableDebugLogging: Bool = false
    var lastDebugExport: Date?
    
    mutating func loadFromDefaults() {
        connectionTimeout = UserDefaults.standard.double(forKey: "connection_timeout")
        if connectionTimeout == 0 { connectionTimeout = 30 }
        
        maxConcurrentDownloads = UserDefaults.standard.integer(forKey: "max_concurrent_downloads")
        if maxConcurrentDownloads == 0 { maxConcurrentDownloads = 3 }
        
        coverCacheLimit = UserDefaults.standard.integer(forKey: "cover_cache_limit")
        if coverCacheLimit == 0 { coverCacheLimit = 100 }
        
        memoryCacheSize = UserDefaults.standard.integer(forKey: "memory_cache_size")
        if memoryCacheSize == 0 { memoryCacheSize = 50 }
        
        enableDebugLogging = UserDefaults.standard.bool(forKey: "enable_debug_logging")
        
        if let lastExportTimestamp = UserDefaults.standard.object(forKey: "last_debug_export") as? TimeInterval {
            lastDebugExport = Date(timeIntervalSince1970: lastExportTimestamp)
        }
    }
    
    func saveNetworkSettings() {
        UserDefaults.standard.set(connectionTimeout, forKey: "connection_timeout")
    }
    
    func saveDownloadSettings() {
        UserDefaults.standard.set(maxConcurrentDownloads, forKey: "max_concurrent_downloads")
    }
    
    func saveCacheSettings() {
        UserDefaults.standard.set(coverCacheLimit, forKey: "cover_cache_limit")
        UserDefaults.standard.set(memoryCacheSize, forKey: "memory_cache_size")
    }
    
    mutating func resetCacheDefaults() {
        coverCacheLimit = 100
        memoryCacheSize = 50
    }
}
