import SwiftUI
import Network

// MARK: - App Loading States

enum AppLoadingState: Equatable {
    case initial
    case loadingCredentials
    case noCredentialsSaved
    case credentialsFoundValidating
    case networkError(ConnectionIssueType)
    case authenticationError
    case loadingData
    case ready
    
    static func == (lhs: AppLoadingState, rhs: AppLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.initial, .initial),
             (.loadingCredentials, .loadingCredentials),
             (.noCredentialsSaved, .noCredentialsSaved),
             (.credentialsFoundValidating, .credentialsFoundValidating),
             (.authenticationError, .authenticationError),
             (.loadingData, .loadingData),
             (.ready, .ready):
            return true
        case (.networkError(let lType), .networkError(let rType)):
            return lType == rType
        default:
            return false
        }
    }
}

// MARK: - Connection Issue Types

enum ConnectionIssueType: Equatable {
    case noInternet
    case serverUnreachable
    case authInvalid
    case serverError
    
    var userMessage: String {
        switch self {
        case .noInternet:
            return "No internet connection"
        case .serverUnreachable:
            return "Cannot reach server"
        case .authInvalid:
            return "Authentication failed"
        case .serverError:
            return "Server error"
        }
    }
    
    var detailMessage: String {
        switch self {
        case .noInternet:
            return "Please check your network settings and try again."
        case .serverUnreachable:
            return "Verify server address and ensure it's running."
        case .authInvalid:
            return "Your credentials are invalid or expired."
        case .serverError:
            return "The server is experiencing issues. Try again later."
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .noInternet, .serverUnreachable, .serverError:
            return true
        case .authInvalid:
            return false
        }
    }
    
    var systemImage: String {
        switch self {
        case .noInternet:
            return "wifi.slash"
        case .serverUnreachable, .serverError:
            return "server.rack"
        case .authInvalid:
            return "key.slash"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .noInternet:
            return .orange
        case .serverUnreachable, .serverError:
            return .red
        case .authInvalid:
            return .yellow
        }
    }
}

// MARK: - App State Manager

class AppStateManager: ObservableObject {
    // MARK: - Published Properties
    @Published var loadingState: AppLoadingState = .initial
    @Published var isFirstLaunch: Bool = false
    @Published var apiClient: AudiobookshelfAPI?
    @Published var showingWelcome = false
    @Published var showingSettings = false
    
    // Network monitoring
    @Published var isDeviceOnline: Bool = true
    @Published var isServerReachable: Bool = true
    
    // MARK: - Private Properties
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.storyteller3.networkmonitor")
    private var lastKnownNetworkStatus: NWPath.Status = .satisfied
    
    // MARK: - Initialization
    init() {
        checkFirstLaunch()
        startNetworkMonitoring()
    }
    
    // MARK: - Public Methods
    
    func clearConnectionIssue() {
        if case .networkError = loadingState {
            loadingState = .initial
        }
    }
    
    func checkServerReachability() async {
        guard isDeviceOnline else {
            await MainActor.run {
                isServerReachable = false
            }
            return
        }
        
        guard let api = apiClient else {
            await MainActor.run {
                isServerReachable = false
            }
            return
        }
        
        let isHealthy = await api.checkConnectionHealth()
        
        await MainActor.run {
            isServerReachable = isHealthy
        }
    }
    
    // MARK: - Private Methods
    
    private func checkFirstLaunch() {
        let hasLaunchedKey = "has_launched_before"
        isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            setupDefaultCacheSettings()
        }
    }
    
    private func setupDefaultCacheSettings() {
        let defaults = UserDefaults.standard
        
        if defaults.coverCacheLimit == 0 {
            defaults.coverCacheLimit = 100
        }
        
        if defaults.memoryCacheSize == 0 {
            defaults.memoryCacheSize = 50
        }
        
        defaults.cacheOptimizationEnabled = true
        defaults.autoCacheCleanup = true
        
        AppLogger.debug.debug("[App] Default cache settings applied")
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let wasOnline = self.lastKnownNetworkStatus == .satisfied
            let isOnline = path.status == .satisfied
            
            self.lastKnownNetworkStatus = path.status
            
            Task { @MainActor in
                self.isDeviceOnline = isOnline
                
                if !isOnline {
                    self.isServerReachable = false
                    AppLogger.debug.debug("[Network] Device went offline")
                } else if !wasOnline && isOnline {
                    AppLogger.debug.debug("[Network] Device came online")
                    await self.checkServerReachability()
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
        AppLogger.debug.debug("[Network] Monitoring started")
    }
    
    deinit {
        networkMonitor.cancel()
    }
}
