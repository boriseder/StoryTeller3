import Foundation
import SwiftUI

@MainActor
final class DependencyContainer: ObservableObject {

    // MARK: - Singleton
    static let shared = DependencyContainer()

    // MARK: - Core Services
    @Published private(set) var apiClient: AudiobookshelfClient?
    lazy var appState: AppStateManager = AppStateManager.shared
    lazy var downloadManager: DownloadManager = DownloadManager()
    lazy var player: AudioPlayer = AudioPlayer()
    lazy var playerStateManager: PlayerStateManager = PlayerStateManager()
    
    lazy var sleepTimerService: SleepTimerService = {
        SleepTimerService(player: player, timerService: TimerService())
    }()
    
    // MARK: - Repositories
    private var _bookRepository: BookRepository?
    private var _libraryRepository: LibraryRepository?
    private var _downloadRepository: DownloadRepository?

    // MARK: - ViewModels (Singletons)
    lazy var homeViewModel: HomeViewModel = {
        HomeViewModel(
            fetchPersonalizedSectionsUseCase: makeFetchPersonalizedSectionsUseCase(),
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            bookRepository: bookRepository,
            api: apiClient!,
            downloadManager: downloadManager,
            player: player,
            appState: appState,
            onBookSelected: {}
        )
    }()

    lazy var libraryViewModel: LibraryViewModel = {
        LibraryViewModel(
            fetchBooksUseCase: makeFetchBooksUseCase(),
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: apiClient!,
            downloadManager: downloadManager,
            player: player,
            appState: appState,
            onBookSelected: {}
        )
    }()

    lazy var seriesViewModel: SeriesViewModel = {
        SeriesViewModel(
            fetchSeriesUseCase: makeFetchSeriesUseCase(),
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: apiClient!,
            downloadManager: downloadManager,
            player: player,
            appState: appState,
            onBookSelected: {}
        )
    }()

    lazy var downloadsViewModel: DownloadsViewModel = {
        DownloadsViewModel(
            downloadManager: downloadManager,
            player: player,
            api: apiClient!,
            appState: appState,
            storageMonitor: storageMonitor,
            onBookSelected: {}
        )
    }()

    lazy var settingsViewModel: SettingsViewModel = {
        SettingsViewModel(
            testConnectionUseCase: makeTestConnectionUseCase(),
            authenticationUseCase: makeAuthenticationUseCase(),
            fetchLibrariesUseCase: makeFetchLibrariesUseCase(),
            calculateStorageUseCase: makeCalculateStorageUseCase(),
            clearCacheUseCase: makeClearCacheUseCase(),
            saveCredentialsUseCase: makeSaveCredentialsUseCase(),
            loadCredentialsUseCase: makeLoadCredentialsUseCase(),
            logoutUseCase: makeLogoutUseCase(),
            serverValidator: serverValidator,
            diagnosticsService: diagnosticsService,
            coverCacheManager: coverCacheManager,
            downloadManager: downloadManager
        )
    }()

    // MARK: - Core Infrastructure
    lazy var storageMonitor: StorageMonitor = StorageMonitor()
    lazy var connectionHealthChecker: ConnectionHealthChecker = ConnectionHealthChecker()
    lazy var keychainService: KeychainService = KeychainService.shared
    lazy var coverCacheManager: CoverCacheManager = CoverCacheManager.shared
    lazy var authService: AuthenticationService = AuthenticationService()
    lazy var serverValidator: ServerConfigValidator = ServerConfigValidator()
    lazy var diagnosticsService: DiagnosticsService = DiagnosticsService()

    private init() {}

    // MARK: - Configure API
    func configureAPI(baseURL: String, token: String) {
        apiClient = AudiobookshelfClient(baseURL: baseURL, authToken: token)
        AppLogger.general.info("[Container] API configured for \(baseURL)")
    }

    // MARK: - Repositories (Lazy Singletons)
    var bookRepository: BookRepository {
        if let existing = _bookRepository { return existing }
        let repo = BookRepository(api: apiClient!)
        _bookRepository = repo
        return repo
    }

    var libraryRepository: LibraryRepository {
        if let existing = _libraryRepository { return existing }
        let repo = LibraryRepository(api: apiClient!, settingsRepository: SettingsRepository())
        _libraryRepository = repo
        return repo
    }

    var downloadRepository: DownloadRepository {
        if let existing = _downloadRepository { return existing }
        guard let repo = downloadManager.repository else {
            fatalError("DownloadManager repository not initialized")
        }
        _downloadRepository = repo
        return repo
    }

    // MARK: - Use Cases
    func makeFetchBooksUseCase() -> FetchBooksUseCase {
        FetchBooksUseCase(bookRepository: bookRepository)
    }

    func makeFetchSeriesUseCase() -> FetchSeriesUseCase {
        FetchSeriesUseCase(bookRepository: bookRepository)
    }

    func makeFetchPersonalizedSectionsUseCase() -> FetchPersonalizedSectionsUseCase {
        FetchPersonalizedSectionsUseCase(bookRepository: bookRepository)
    }

    func makeSyncProgressUseCase() -> SyncProgressUseCase {
        SyncProgressUseCase(playbackRepository: PlaybackRepository(), api: apiClient!)
    }

    func makeTestConnectionUseCase() -> TestConnectionUseCase {
        TestConnectionUseCase(connectionHealthChecker: connectionHealthChecker)
    }

    func makeAuthenticationUseCase() -> AuthenticationUseCase {
        AuthenticationUseCase(authService: authService, keychainService: keychainService)
    }

    func makeFetchLibrariesUseCase() -> FetchLibrariesUseCase {
        FetchLibrariesUseCase()
    }

    func makeCalculateStorageUseCase() -> CalculateStorageUseCase {
        CalculateStorageUseCase(storageMonitor: storageMonitor, downloadManager: downloadManager)
    }

    func makeClearCacheUseCase() -> ClearCacheUseCase {
        ClearCacheUseCase(coverCacheManager: coverCacheManager)
    }

    func makeSaveCredentialsUseCase() -> SaveCredentialsUseCase {
        SaveCredentialsUseCase(keychainService: keychainService)
    }

    func makeLoadCredentialsUseCase() -> LoadCredentialsUseCase {
        LoadCredentialsUseCase(keychainService: keychainService, authService: authService)
    }

    func makeLogoutUseCase() -> LogoutUseCase {
        LogoutUseCase(keychainService: keychainService)
    }

    // MARK: - Reset
    func resetRepositories() {
        _bookRepository = nil
        _libraryRepository = nil
        _downloadRepository = nil
    }

    @MainActor
    func reset() {
        AppLogger.general.info("[Container] Factory reset initiated")

        bookRepository.clearCache()
        libraryRepository.clearCache()
        _bookRepository = nil
        _libraryRepository = nil
        _downloadRepository = nil

        AppLogger.general.info("[Container] All repositories reset")
    }
}


