import SwiftUI

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
            return "icloud.slash"
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
    @Published var apiClient: AudiobookshelfClient?
    @Published var showingWelcome = false
    @Published var showingSettings = false
    
    // Network monitoring
    @Published var isDeviceOnline: Bool = true
    @Published var isServerReachable: Bool = true
    
    // MARK: - Dependencies
    private let networkMonitor: NetworkMonitor
    private let connectionHealthChecker: ConnectionHealthChecking
    
    // MARK: - Initialization
    init(
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        connectionHealthChecker: ConnectionHealthChecking = ConnectionHealthChecker()
    ) {
        self.networkMonitor = networkMonitor
        self.connectionHealthChecker = connectionHealthChecker
        
        checkFirstLaunch()
        setupNetworkMonitoring()
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
        
        let health = await connectionHealthChecker.checkHealth(
            baseURL: api.baseURLString,
            token: api.authToken
        )
        
        await MainActor.run {
            isServerReachable = health != .unavailable
        }
    }
    
    // MARK: - Private Methods
    
    private func checkFirstLaunch() {
        let hasStoredCredentials = UserDefaults.standard.string(forKey: "stored_username") != nil
        isFirstLaunch = !hasStoredCredentials
        
        if isFirstLaunch && !UserDefaults.standard.bool(forKey: "defaults_configured") {
            UserDefaults.standard.set(true, forKey: "defaults_configured")
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.onStatusChange { [weak self] (status: NetworkStatus) in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let isOnline = status == .online
                let wasOnline = self.isDeviceOnline
                
                self.isDeviceOnline = isOnline
                
                if !isOnline {
                    self.isServerReachable = false
                    AppLogger.general.info("[AppState] Device went offline")
                } else if !wasOnline && isOnline {
                    AppLogger.general.info("[AppState] Device came online")
                    await self.checkServerReachability()
                }
            }
        }
        
        networkMonitor.startMonitoring()
        AppLogger.general.info("[AppState] Network monitoring started")
    }
}
