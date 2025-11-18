
import SwiftUI

// MARK: - App Loading States
// Represents the high-level loading and authentication phases of the app lifecycle.
enum AppLoadingState: Equatable {
    case initial
    case loadingCredentials
    case noCredentialsSaved
    case credentialsFoundValidating
    case networkError(ConnectionIssueType)
    case authenticationError
    case loadingData
    case ready
}

// MARK: - Connection Issue Types
// Describes different types of network or authentication issues.
enum ConnectionIssueType: Equatable {
    case noInternet
    case serverUnreachable
    case authInvalid
    case serverError

    // User-facing short message.
    var userMessage: String {
        switch self {
        case .noInternet: return "No internet connection"
        case .serverUnreachable: return "Cannot reach server"
        case .authInvalid: return "Authentication failed"
        case .serverError: return "Server error"
        }
    }

    // Additional details for UI.
    var detailMessage: String {
        switch self {
        case .noInternet: return "Please check your network settings and try again."
        case .serverUnreachable: return "Verify server address and ensure it's running."
        case .authInvalid: return "Your credentials are invalid or expired."
        case .serverError: return "The server is experiencing issues. Try again later."
        }
    }

    // Defines whether the error can be retried.
    var canRetry: Bool {
        switch self {
        case .noInternet, .serverUnreachable, .serverError: return true
        case .authInvalid: return false
        }
    }

    // System image used for visual feedback.
    var systemImage: String {
        switch self {
        case .noInternet: return "wifi.slash"
        case .serverUnreachable, .serverError: return "icloud.slash"
        case .authInvalid: return "key.slash"
        }
    }

    // Icon color displayed in alerts.
    var iconColor: Color {
        switch self {
        case .noInternet: return .orange
        case .serverUnreachable, .serverError: return .red
        case .authInvalid: return .yellow
        }
    }
}


// MARK: - Network Availability Helpers
// Indicates high-level network availability.
/*
enum NetworkAvailability: Equatable {
    case available
    case noInternet
    case serverUnreachable

    var isAvailable: Bool {
        self == .available
    }

    var userMessage: String {
        switch self {
        case .available: return ""
        case .noInternet: return "No internet connection"
        case .serverUnreachable: return "Server unreachable"
        }
    }
}
*/

// MARK: - App State Manager
// Central observable manager for app lifecycle, networking state, and UI flags.
class AppStateManager: ObservableObject {
    static let shared = AppStateManager()

    @Published var loadingState: AppLoadingState = .initial
    @Published var isFirstLaunch: Bool = false
    @Published var showingWelcome = false
    @Published var showingSettings = false

    @Published var isDeviceOnline: Bool = true
    @Published var isServerReachable: Bool = true

    @Published var selectedTab: TabIndex = .home

    private let networkMonitor: NetworkMonitor
    private let connectionHealthChecker: ConnectionHealthChecking

    init(
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        connectionHealthChecker: ConnectionHealthChecking = ConnectionHealthChecker()
    ) {
        self.networkMonitor = networkMonitor
        self.connectionHealthChecker = connectionHealthChecker

        checkFirstLaunch()
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.onStatusChange { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }

                switch status {
                case .offline:
                    self.isDeviceOnline = false
                    self.isServerReachable = false
                    AppLogger.general.info("[AppState] Device went offline")
                case .online:
                    AppLogger.general.info("[AppState] Device online – verifying server...")
                    self.networkMonitor.forceRefresh()
                    await self.checkServerReachability()
                    self.verifyConnectionHealth()
                case .unknown:
                    self.isDeviceOnline = false
                    self.isServerReachable = false
                }
            }
        }
        networkMonitor.startMonitoring()
        AppLogger.general.info("[AppState] Network monitoring started")
    }

    // MARK: - Self-Healing NWPathMonitor
    private func verifyConnectionHealth() {
        Task { @MainActor in
            guard networkMonitor.currentStatus == .online else { return }

            // Kurze Verzögerung, um NWPathMonitor-Bug abzufangen
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 Sekunden

            // Force Refresh
            networkMonitor.forceRefresh()
            
            // Prüfe Server erneut
            await checkServerReachability()
            
            AppLogger.general.debug("[AppState] Connection health verified after self-heal")
        }
    }

    // MARK: - Server Reachability
    func checkServerReachability() async {
        guard let api = await DependencyContainer.shared.apiClient else { return }

        let monitorStatus = networkMonitor.currentStatus

        let health = await connectionHealthChecker.checkHealth(
            baseURL: api.baseURLString,
            token: api.authToken
        )

        await MainActor.run {
            self.isDeviceOnline = monitorStatus == .online
            self.isServerReachable = health != .unavailable
        }
    }
/*
    func getNetworkAvailability() -> NetworkAvailability {
        if !isDeviceOnline { return .noInternet }
        if !isServerReachable { return .serverUnreachable }
        return .available
    }
*/
    
    func clearConnectionIssue() {
        if case .networkError = loadingState {
            loadingState = .initial
        }
    }

    private func checkFirstLaunch() {
        let hasStoredCredentials = UserDefaults.standard.string(forKey: "stored_username") != nil
        isFirstLaunch = !hasStoredCredentials

        if isFirstLaunch && !UserDefaults.standard.bool(forKey: "defaults_configured") {
            UserDefaults.standard.set(true, forKey: "defaults_configured")
        }
    }
}

