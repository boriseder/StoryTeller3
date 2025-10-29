import Foundation

// MARK: - Dependency Container
// Central dependency management following Clean Architecture principles
// Provides singleton instances and factory methods for all major components

final class DependencyContainer: ObservableObject {

    // MARK: - Singleton
    @MainActor
    static let shared = DependencyContainer()
    
    // MARK: - Core Services (Singleton)
    @MainActor
    private(set) lazy var keychainService: KeychainService = {
        KeychainService.shared
    }()
    
    @MainActor
    private(set) lazy var coverCacheManager: CoverCacheManager = {
        CoverCacheManager.shared
    }()
    
    // MARK: - Infrastructure Services
    @MainActor
    private(set) lazy var connectionHealthChecker: ConnectionHealthChecker = {
        ConnectionHealthChecker()
    }()
    
    @MainActor
    private(set) lazy var storageMonitor: StorageMonitor = {
        StorageMonitor()
    }()
    
    @MainActor
    private(set) lazy var serverValidator: ServerConfigValidator = {
        ServerConfigValidator()
    }()
    
    @MainActor
    private(set) lazy var diagnosticsService: DiagnosticsService = {
        DiagnosticsService()
    }()
    
    @MainActor
    private(set) lazy var authService: AuthenticationService = {
        AuthenticationService()
    }()
    
    // MARK: - Managers (Singleton - shared state)
    @MainActor
    private(set) lazy var downloadManager: DownloadManager = {
        DownloadManager()
    }()
    
    @MainActor
    private(set) lazy var player: AudioPlayer = {
        AudioPlayer()
    }()
    
    @MainActor
    private(set) lazy var playerStateManager: PlayerStateManager = {
        PlayerStateManager()
    }()
    
    // MARK: - Private Init
    private init() {}
    
    // MARK: - Repository Factory Methods
    @MainActor
    func makeBookRepository(api: AudiobookshelfClient) -> BookRepository {
        BookRepository(api: api, cache: BookCache())
    }
    
    @MainActor
    func makeLibraryRepository(api: AudiobookshelfClient, settingsRepository: SettingsRepository? = nil) -> LibraryRepository {
        LibraryRepository(api: api, settingsRepository: settingsRepository ?? SettingsRepository())
    }
    
    @MainActor
    func makePlaybackRepository() -> PlaybackRepository {
        PlaybackRepository()
    }
    
    @MainActor
    func makeSettingsRepository() -> SettingsRepository {
        SettingsRepository()
    }
    
    @MainActor
    func makeDownloadRepository() -> DownloadRepository {
        guard let repository = downloadManager.repository else {
            fatalError("DownloadManager not initialized. Ensure setup() is called first.")
        }
        return repository
    }
    
    // MARK: - Use Case Factory Methods
    @MainActor
    func makeFetchBooksUseCase(api: AudiobookshelfClient) -> FetchBooksUseCase {
        let bookRepository = makeBookRepository(api: api)
        return FetchBooksUseCase(bookRepository: bookRepository)
    }
    
    @MainActor
    func makeFetchSeriesUseCase(api: AudiobookshelfClient) -> FetchSeriesUseCase {
        let bookRepository = makeBookRepository(api: api)
        return FetchSeriesUseCase(bookRepository: bookRepository)
    }
    
    @MainActor
    func makeFetchPersonalizedSectionsUseCase(api: AudiobookshelfClient) -> FetchPersonalizedSectionsUseCase {
        let bookRepository = makeBookRepository(api: api)
        return FetchPersonalizedSectionsUseCase(bookRepository: bookRepository)
    }
    
    @MainActor
    func makeSyncProgressUseCase(api: AudiobookshelfClient) -> SyncProgressUseCase {
        let playbackRepository = makePlaybackRepository()
        return SyncProgressUseCase(playbackRepository: playbackRepository, api: api)
    }
    
    @MainActor
    func makeTestConnectionUseCase() -> TestConnectionUseCase {
        TestConnectionUseCase(connectionHealthChecker: connectionHealthChecker)
    }
    
    @MainActor
    func makeAuthenticationUseCase() -> AuthenticationUseCase {
        AuthenticationUseCase(authService: authService, keychainService: keychainService)
    }
    
    @MainActor
    func makeFetchLibrariesUseCase() -> FetchLibrariesUseCase {
        FetchLibrariesUseCase()
    }
    
    @MainActor
    func makeCalculateStorageUseCase() -> CalculateStorageUseCase {
        CalculateStorageUseCase(storageMonitor: storageMonitor, downloadManager: downloadManager)
    }
    
    @MainActor
    func makeClearCacheUseCase() -> ClearCacheUseCase {
        ClearCacheUseCase(coverCacheManager: coverCacheManager)
    }
    
    @MainActor
    func makeSaveCredentialsUseCase() -> SaveCredentialsUseCase {
        SaveCredentialsUseCase(keychainService: keychainService)
    }
    
    @MainActor
    func makeLoadCredentialsUseCase() -> LoadCredentialsUseCase {
        LoadCredentialsUseCase(keychainService: keychainService, authService: authService)
    }
    
    @MainActor
    func makeLogoutUseCase() -> LogoutUseCase {
        LogoutUseCase(keychainService: keychainService)
    }
}
