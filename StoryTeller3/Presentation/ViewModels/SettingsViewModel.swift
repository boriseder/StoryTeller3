import SwiftUI

class SettingsViewModel: ObservableObject {
    // MARK: - Server Configuration
    @Published var scheme: String = "http"
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
    // MARK: - Connection State
    @Published var connectionState: ConnectionState = .initial
    @Published var isTestingConnection = false
    @Published var libraries: [Library] = []
    @Published var selectedLibraryId: String?
    @Published var isLoggedIn: Bool = false
    
    // MARK: - Storage Info
    @Published var totalCacheSize: String = "Calculating..."
    @Published var downloadedBooksCount: Int = 0
    @Published var totalDownloadSize: String = "Calculating..."
    @Published var isCalculatingStorage = false
    
    // MARK: - Advanced Settings
    @Published var connectionTimeout: Double = 30
    @Published var maxConcurrentDownloads: Int = 3
    @Published var coverCacheLimit: Int = 100
    @Published var memoryCacheSize: Int = 50
    @Published var enableDebugLogging = false
    @Published var lastDebugExport: Date?
    
    // MARK: - UI State
    @Published var showingClearCacheAlert = false
    @Published var showingClearDownloadsAlert = false
    @Published var showingLogoutAlert = false
    @Published var showingTestResults = false
    @Published var testResultMessage: String = ""
    @Published var cacheOperationInProgress = false
    @Published var lastCacheCleanupDate: Date?
    @Published var showingShareSheet = false
    @Published var shareURL: URL?
    
    // MARK: - Dependencies
    private var apiClient: AudiobookshelfAPI?
    private let authService = AuthenticationService()
    private let keychainService = KeychainService.shared
    let downloadManager = DownloadManager()
    let coverCacheManager = CoverCacheManager.shared
    
    private let serverValidator: ServerConfigValidating
    private let storageMonitor: StorageMonitoring
    private let connectionHealthChecker: ConnectionHealthChecking
    private let diagnosticsService: DiagnosticsCollecting
    
    // MARK: - Computed Properties
    
    var fullServerURL: String {
        let portString = port.isEmpty ? "" : ":\(port)"
        return "\(scheme)://\(host)\(portString)"
    }
    
    var isServerConfigured: Bool {
        !host.isEmpty
    }
    
    var canTestConnection: Bool {
        isServerConfigured && !isTestingConnection
    }
    
    var canLogin: Bool {
        isServerConfigured && !username.isEmpty && !password.isEmpty && !isLoggedIn
    }
    
    // MARK: - Initialization
    
    init(
        serverValidator: ServerConfigValidating = ServerConfigValidator(),
        storageMonitor: StorageMonitoring = StorageMonitor(),
        connectionHealthChecker: ConnectionHealthChecking = ConnectionHealthChecker(),
        diagnosticsService: DiagnosticsCollecting = DiagnosticsService()
    ) {
        self.serverValidator = serverValidator
        self.storageMonitor = storageMonitor
        self.connectionHealthChecker = connectionHealthChecker
        self.diagnosticsService = diagnosticsService
        
        loadSavedSettings()
        loadAdvancedSettings()
    }
    
    // MARK: - Connection State Management
    
    enum ConnectionState: Equatable {
        case initial
        case testing
        case serverFound
        case authenticated
        case failed(String)
        
        var statusText: String {
            switch self {
            case .initial: return ""
            case .testing: return "Testing connection..."
            case .serverFound: return "Server found - please login"
            case .authenticated: return "Connected"
            case .failed(let error): return error
            }
        }
        
        var statusColor: Color {
            switch self {
            case .initial: return .secondary
            case .testing: return .blue
            case .serverFound: return .orange
            case .authenticated: return .green
            case .failed: return .red
            }
        }
    }
    
    // MARK: - Connection Testing
    
    func testConnection() {
        guard canTestConnection else { return }
        
        let config = ServerConfig(scheme: scheme, host: host, port: port)
        
        switch serverValidator.validateServerConfig(config) {
        case .failure(let error):
            connectionState = .failed(error.localizedDescription)
            return
        case .success:
            break
        }
        
        isTestingConnection = true
        connectionState = .testing
        
        let baseURL = fullServerURL
        
        Task {
            let canPing = await connectionHealthChecker.ping(baseURL: baseURL)
            
            await MainActor.run {
                self.isTestingConnection = false
                
                if canPing {
                    self.connectionState = .serverFound
                    self.testResultMessage = """
                    Server Status: Online
                    URL: \(baseURL)
                    
                    Please enter credentials to login.
                    """
                    self.showingTestResults = true
                } else {
                    self.connectionState = .failed("Server unreachable")
                }
            }
        }
    }
    
    // MARK: - Input Validation
    
    func sanitizeHost() {
        host = serverValidator.sanitizeHost(host)
    }
    
    // MARK: - Authentication
    
    func login() {
        guard canLogin else { return }
        
        isTestingConnection = true
        connectionState = .testing
        
        let baseURL = fullServerURL
        
        Task {
            do {
                let token = try await authService.login(
                    baseURL: baseURL,
                    username: username,
                    password: password
                )
                
                await MainActor.run {
                    self.isTestingConnection = false
                    self.connectionState = .authenticated
                    self.isLoggedIn = true
                    
                    self.storeCredentials(baseURL: baseURL, token: token)
                    self.apiClient = AudiobookshelfAPI(baseURL: baseURL, apiKey: token)
                    
                    self.fetchLibrariesAndSave()
                    
                    self.testResultMessage = """
                    Authentication Successful
                    
                    User: \(self.username)
                    Server: \(baseURL)
                    
                    Loading libraries...
                    """
                    self.showingTestResults = true
                }
            } catch {
                await MainActor.run {
                    self.isTestingConnection = false
                    self.connectionState = .failed("Authentication failed: \(error.localizedDescription)")
                    self.isLoggedIn = false
                }
            }
        }
    }
    
    func logout() {
        do {
            try keychainService.clearAllCredentials()
        } catch {
            AppLogger.debug.debug("Failed to clear keychain: \(error)")
        }
        
        apiClient = nil
        libraries = []
        selectedLibraryId = nil
        connectionState = .initial
        isLoggedIn = false
        
        UserDefaults.standard.removeObject(forKey: "server_scheme")
        UserDefaults.standard.removeObject(forKey: "server_host")
        UserDefaults.standard.removeObject(forKey: "server_port")
        UserDefaults.standard.removeObject(forKey: "stored_username")
        UserDefaults.standard.removeObject(forKey: "baseURL")
        UserDefaults.standard.removeObject(forKey: "apiKey")
        UserDefaults.standard.removeObject(forKey: "selected_library_id")
        
        username = ""
        password = ""
        
        NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
        
        Task {
            await CoverDownloadManager.shared.shutdown()
        }
    }
    
    // MARK: - Storage Management
    
    func calculateStorageInfo() async {
        await MainActor.run {
            isCalculatingStorage = true
        }
        
        let cacheSize = await calculateTotalCacheSize()
        let downloadsCount = downloadManager.downloadedBooks.count
        let downloadsSize = calculateDownloadSize()
        
        await MainActor.run {
            totalCacheSize = cacheSize
            downloadedBooksCount = downloadsCount
            totalDownloadSize = downloadsSize
            isCalculatingStorage = false
        }
    }
    
    private func calculateTotalCacheSize() async -> String {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let totalSize = storageMonitor.calculateDirectorySize(at: cacheURL)
        return storageMonitor.formatBytes(totalSize)
    }
    
    func clearAllCache() async {
        await MainActor.run {
            cacheOperationInProgress = true
        }
        
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheURL,
                includingPropertiesForKeys: nil
            )
            
            for item in contents {
                try? FileManager.default.removeItem(at: item)
            }
            
            await MainActor.run {
                coverCacheManager.clearAllCache()
                lastCacheCleanupDate = Date()
            }
        } catch {
            AppLogger.debug.debug("Cache cleanup error: \(error)")
        }
        
        await calculateStorageInfo()
        
        await MainActor.run {
            cacheOperationInProgress = false
        }
    }
    
    func clearAllDownloads() async {
        downloadManager.deleteAllBooks()
        await calculateStorageInfo()
    }
    
    // MARK: - Advanced Settings
    
    private func loadAdvancedSettings() {
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
        
        Task { @MainActor in
            coverCacheManager.updateCacheLimits()
        }
    }
    
    func resetCacheDefaults() {
        coverCacheLimit = 100
        memoryCacheSize = 50
        saveCacheSettings()
    }
    
    func toggleDebugLogging(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enable_debug_logging")
    }
    
    func exportDebugLogs() {
        lastDebugExport = Date()
        UserDefaults.standard.set(lastDebugExport?.timeIntervalSince1970, forKey: "last_debug_export")
        
        diagnosticsService.exportLogs { [weak self] url in
            guard let url = url else {
                AppLogger.debug.debug("[Settings] Failed to export logs")
                return
            }
            
            Task { @MainActor in
                self?.shareURL = url
                self?.showingShareSheet = true
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadSavedSettings() {
        scheme = UserDefaults.standard.string(forKey: "server_scheme") ?? "http"
        host = UserDefaults.standard.string(forKey: "server_host") ?? ""
        port = UserDefaults.standard.string(forKey: "server_port") ?? ""
        
        if let savedUsername = UserDefaults.standard.string(forKey: "stored_username") {
            username = savedUsername
            
            do {
                password = try keychainService.getPassword(for: savedUsername)
                let token = try keychainService.getToken(for: savedUsername)
                
                if let baseURL = UserDefaults.standard.string(forKey: "baseURL") {
                    Task {
                        do {
                            let isValid = try await authService.validateToken(baseURL: baseURL, token: token)
                            await MainActor.run {
                                if isValid {
                                    self.isLoggedIn = true
                                    self.connectionState = .authenticated
                                    self.apiClient = AudiobookshelfAPI(baseURL: baseURL, apiKey: token)
                                    self.loadLibraries()
                                } else {
                                    self.connectionState = .failed("Token expired - please login again")
                                }
                            }
                        } catch {
                            await MainActor.run {
                                self.connectionState = .failed("Token validation failed")
                            }
                        }
                    }
                }
            } catch {
                connectionState = .initial
            }
        }
    }
    
    private func storeCredentials(baseURL: String, token: String) {
        do {
            try keychainService.storePassword(password, for: username)
            try keychainService.storeToken(token, for: username)
            
            UserDefaults.standard.set(scheme, forKey: "server_scheme")
            UserDefaults.standard.set(host, forKey: "server_host")
            UserDefaults.standard.set(port, forKey: "server_port")
            UserDefaults.standard.set(username, forKey: "stored_username")
            UserDefaults.standard.set(baseURL, forKey: "baseURL")
            
            NotificationCenter.default.post(name: .init("ServerSettingsChanged"), object: nil)
            
            AppLogger.debug.debug("Credentials stored successfully")
            
        } catch {
            AppLogger.debug.debug("Failed to store credentials: \(error)")
            connectionState = .failed("Failed to save credentials")
            
            testResultMessage = """
            Failed to Save Credentials
            
            Error: \(error.localizedDescription)
            
            Your login was successful, but we couldn't save the credentials securely.
            Please try logging in again.
            """
            showingTestResults = true
        }
    }
   
    private func fetchLibrariesAndSave() {
        guard let client = apiClient else { return }
        
        Task {
            do {
                let libs = try await client.fetchLibraries()
                await MainActor.run {
                    self.libraries = libs
                    self.restoreSelectedLibrary()
                }
            } catch {
                await MainActor.run {
                    self.connectionState = .failed("Failed to load libraries")
                }
            }
        }
    }
    
    private func loadLibraries() {
        guard let client = apiClient else { return }
        Task {
            do {
                let libs = try await client.fetchLibraries()
                await MainActor.run {
                    self.libraries = libs
                    self.restoreSelectedLibrary()
                }
            } catch {
                await MainActor.run {
                    self.connectionState = .failed("Failed to load libraries")
                }
            }
        }
    }
    
    private func restoreSelectedLibrary() {
        if let savedId = UserDefaults.standard.string(forKey: "selected_library_id"),
           libraries.contains(where: { $0.id == savedId }) {
            selectedLibraryId = savedId
        } else if let defaultLibrary = libraries.first(where: { $0.name.lowercased().contains("default") }) {
            selectedLibraryId = defaultLibrary.id
            saveSelectedLibrary(defaultLibrary.id)
        } else if let firstLibrary = libraries.first {
            selectedLibraryId = firstLibrary.id
            saveSelectedLibrary(firstLibrary.id)
        }
    }
    
    func saveSelectedLibrary(_ libraryId: String?) {
        if let id = libraryId {
            LibraryHelpers.saveLibrarySelection(id)
        } else {
            LibraryHelpers.saveLibrarySelection(nil)
        }
    }
    
    private func calculateDownloadSize() -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadsURL = documentsURL.appendingPathComponent("Downloads")
        let size = storageMonitor.calculateDirectorySize(at: downloadsURL)
        return storageMonitor.formatBytes(size)
    }
}
