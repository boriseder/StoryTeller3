import Foundation

@MainActor
struct SettingsViewModelFactory {
    static func create() -> SettingsViewModel {
        let connectionHealthChecker = ConnectionHealthChecker()
        let storageMonitor = StorageMonitor()
        let authService = AuthenticationService()
        let keychainService = KeychainService.shared
        
        let testConnectionUseCase = TestConnectionUseCase(
            connectionHealthChecker: connectionHealthChecker
        )
        
        let authenticationUseCase = AuthenticationUseCase(
            authService: authService,
            keychainService: keychainService
        )
        
        let fetchLibrariesUseCase = FetchLibrariesUseCase()
        
        let downloadManager = DownloadManager()
        
        let calculateStorageUseCase = CalculateStorageUseCase(
            storageMonitor: storageMonitor,
            downloadManager: downloadManager
        )
        
        let clearCacheUseCase = ClearCacheUseCase(
            coverCacheManager: CoverCacheManager.shared
        )
        
        let saveCredentialsUseCase = SaveCredentialsUseCase(
            keychainService: keychainService
        )
        
        let loadCredentialsUseCase = LoadCredentialsUseCase(
            keychainService: keychainService,
            authService: authService
        )
        
        let logoutUseCase = LogoutUseCase(
            keychainService: keychainService
        )
        
        let serverValidator = ServerConfigValidator()
        let diagnosticsService = DiagnosticsService()
        
        return SettingsViewModel(
            testConnectionUseCase: testConnectionUseCase,
            authenticationUseCase: authenticationUseCase,
            fetchLibrariesUseCase: fetchLibrariesUseCase,
            calculateStorageUseCase: calculateStorageUseCase,
            clearCacheUseCase: clearCacheUseCase,
            saveCredentialsUseCase: saveCredentialsUseCase,
            loadCredentialsUseCase: loadCredentialsUseCase,
            logoutUseCase: logoutUseCase,
            serverValidator: serverValidator,
            diagnosticsService: diagnosticsService,
            coverCacheManager: CoverCacheManager.shared,
            downloadManager: downloadManager
        )
    }
}
