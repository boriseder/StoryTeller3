import Foundation

// MARK: - Server Configuration
struct StoredServerConfig {
    let scheme: String
    let host: String
    let port: String
    let username: String
    
    var fullURL: String {
        let portString = port.isEmpty ? "" : ":\(port)"
        return "\(scheme)://\(host)\(portString)"
    }
}

// MARK: - App Settings
struct AppSettings {
    var connectionTimeout: Double
    var maxConcurrentDownloads: Int
    var coverCacheLimit: Int
    var memoryCacheSize: Int
    var enableDebugLogging: Bool
    var autoCacheCleanup: Bool
    var cacheOptimizationEnabled: Bool
    var openFullscreenPlayer: Bool
    var autoPlayOnBookTap: Bool

}

// MARK: - Repository Protocol
protocol SettingsRepositoryProtocol {
    func getServerConfig() -> StoredServerConfig?
    func saveServerConfig(_ config: ServerConfig)
    func clearServerConfig()
    
    func getCredentials(for username: String) throws -> (password: String, token: String)
    func saveCredentials(username: String, password: String, token: String) throws
    func clearCredentials(for username: String) throws
    
    func getAppSettings() -> AppSettings
    func saveAppSettings(_ settings: AppSettings)
    func resetToDefaults()
    
    func getSelectedLibraryId() -> String?
    func saveSelectedLibraryId(_ libraryId: String?)
}

// MARK: - Settings Repository Implementation
class SettingsRepository: SettingsRepositoryProtocol {
    
    private let userDefaults: UserDefaults
    private let keychainService: KeychainService
    
    init(
        userDefaults: UserDefaults = .standard,
        keychainService: KeychainService = .shared
    ) {
        self.userDefaults = userDefaults
        self.keychainService = keychainService
    }
    
    // MARK: - Server Configuration
    
    func getServerConfig() -> StoredServerConfig? {
        guard let host = userDefaults.string(forKey: "server_host"),
              !host.isEmpty else {
            return nil
        }
        
        return StoredServerConfig(
            scheme: userDefaults.string(forKey: "server_scheme") ?? "http",
            host: host,
            port: userDefaults.string(forKey: "server_port") ?? "",
            username: userDefaults.string(forKey: "stored_username") ?? ""
        )
    }
    
    func saveServerConfig(_ config: ServerConfig) {
        userDefaults.set(config.scheme, forKey: "server_scheme")
        userDefaults.set(config.host, forKey: "server_host")
        userDefaults.set(config.port, forKey: "server_port")
        userDefaults.set(config.fullURL, forKey: "baseURL")
        
        AppLogger.general.debug("[SettingsRepository] Saved server config: \(config.fullURL)")
    }
    
    func clearServerConfig() {
        userDefaults.removeObject(forKey: "server_scheme")
        userDefaults.removeObject(forKey: "server_host")
        userDefaults.removeObject(forKey: "server_port")
        userDefaults.removeObject(forKey: "stored_username")
        userDefaults.removeObject(forKey: "baseURL")
        userDefaults.removeObject(forKey: "apiKey")
        
        AppLogger.general.debug("[SettingsRepository] Cleared server config")
    }
    
    // MARK: - Credentials Management
    
    func getCredentials(for username: String) throws -> (password: String, token: String) {
        let password = try keychainService.getPassword(for: username)
        let token = try keychainService.getToken(for: username)
        return (password, token)
    }
    
    func saveCredentials(username: String, password: String, token: String) throws {
        try keychainService.storePassword(password, for: username)
        try keychainService.storeToken(token, for: username)
        
        userDefaults.set(username, forKey: "stored_username")
        
        AppLogger.general.debug("[SettingsRepository] Saved credentials for user: \(username)")
    }
    
    func clearCredentials(for username: String) throws {
        try keychainService.clearAllCredentials()
        userDefaults.removeObject(forKey: "stored_username")
        
        AppLogger.general.debug("[SettingsRepository] Cleared credentials")
    }
    
    // MARK: - App Settings
    
    func getAppSettings() -> AppSettings {
        AppSettings(
            connectionTimeout: userDefaults.double(forKey: "connection_timeout").orDefault(30.0),
            maxConcurrentDownloads: userDefaults.integer(forKey: "max_concurrent_downloads").orDefault(3),
            coverCacheLimit: userDefaults.integer(forKey: "cover_cache_limit").orDefault(100),
            memoryCacheSize: userDefaults.integer(forKey: "memory_cache_size").orDefault(50),
            enableDebugLogging: userDefaults.bool(forKey: "enable_debug_logging"),
            autoCacheCleanup: userDefaults.bool(forKey: "auto_cache_cleanup"),
            cacheOptimizationEnabled: userDefaults.bool(forKey: "cache_optimization_enabled"),
            openFullscreenPlayer: userDefaults.bool(forKey: "open_fullscreen_player"),
            autoPlayOnBookTap: userDefaults.bool(forKey: "auto_play_on_book_tap")
        )
    }
    
    func saveAppSettings(_ settings: AppSettings) {
        userDefaults.set(settings.connectionTimeout, forKey: "connection_timeout")
        userDefaults.set(settings.maxConcurrentDownloads, forKey: "max_concurrent_downloads")
        userDefaults.set(settings.coverCacheLimit, forKey: "cover_cache_limit")
        userDefaults.set(settings.memoryCacheSize, forKey: "memory_cache_size")
        userDefaults.set(settings.enableDebugLogging, forKey: "enable_debug_logging")
        userDefaults.set(settings.autoCacheCleanup, forKey: "auto_cache_cleanup")
        userDefaults.set(settings.cacheOptimizationEnabled, forKey: "cache_optimization_enabled")
        userDefaults.set(settings.openFullscreenPlayer, forKey: "open_fullscreen_player")
        userDefaults.set(settings.autoPlayOnBookTap, forKey: "auto_play_on_book_tap")

        AppLogger.general.debug("[SettingsRepository] Saved app settings")
    }
    
    func resetToDefaults() {
        let defaults = AppSettings(
            connectionTimeout: 30.0,
            maxConcurrentDownloads: 3,
            coverCacheLimit: 100,
            memoryCacheSize: 50,
            enableDebugLogging: false,
            autoCacheCleanup: true,
            cacheOptimizationEnabled: true,
            openFullscreenPlayer: false,
            autoPlayOnBookTap: false

        )
        
        saveAppSettings(defaults)
        
        AppLogger.general.debug("[SettingsRepository] Reset to default settings")
    }
    
    // MARK: - Library Selection
    
    func getSelectedLibraryId() -> String? {
        userDefaults.string(forKey: "selected_library_id")
    }
    
    func saveSelectedLibraryId(_ libraryId: String?) {
        if let id = libraryId {
            userDefaults.set(id, forKey: "selected_library_id")
            AppLogger.general.debug("[SettingsRepository] Saved library selection: \(id)")
        } else {
            userDefaults.removeObject(forKey: "selected_library_id")
            AppLogger.general.debug("[SettingsRepository] Cleared library selection")
        }
    }
}

// MARK: - Helper Extensions
private extension Double {
    func orDefault(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}

private extension Int {
    func orDefault(_ defaultValue: Int) -> Int {
        self == 0 ? defaultValue : self
    }
}

// MARK: - Settings Errors
enum SettingsError: LocalizedError {
    case credentialsNotFound
    case keychainError(Error)
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "No saved credentials found"
        case .keychainError(let error):
            return "Keychain error: \(error.localizedDescription)"
        case .invalidConfiguration:
            return "Invalid server configuration"
        }
    }
}
