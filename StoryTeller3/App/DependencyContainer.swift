import Foundation
import SwiftUI

// MARK: - Configuration Error
enum DependencyError: Error {
    case apiNotConfigured
    case repositoryNotInitialized(String)
    
    var localizedDescription: String {
        switch self {
        case .apiNotConfigured:
            return "API client must be configured before accessing dependencies"
        case .repositoryNotInitialized(let name):
            return "\(name) repository not initialized"
        }
    }
}

@MainActor
final class DependencyContainer: ObservableObject {

    // MARK: - Singleton
    static let shared = DependencyContainer()

    // MARK: - Configuration State
    @Published private(set) var isConfigured = false

    // MARK: - Core Services
    private var _apiClient: AudiobookshelfClient?
    var apiClient: AudiobookshelfClient? {
        _apiClient
    }
    
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
    lazy var playbackRepository: PlaybackRepository = PlaybackRepository.shared

    // MARK: - ViewModels (Lazy mit Safety)
    private var _homeViewModel: HomeViewModel?
    private var _libraryViewModel: LibraryViewModel?
    private var _seriesViewModel: SeriesViewModel?
    private var _authorsViewModel: AuthorsViewModel?
    private var _downloadsViewModel: DownloadsViewModel?
    private var _settingsViewModel: SettingsViewModel?

    // MARK: - Core Infrastructure
    lazy var storageMonitor: StorageMonitor = StorageMonitor()
    lazy var connectionHealthChecker: ConnectionHealthChecker = ConnectionHealthChecker()
    lazy var keychainService: KeychainService = KeychainService.shared
    lazy var coverCacheManager: CoverCacheManager = CoverCacheManager.shared
    lazy var authService: AuthenticationService = AuthenticationService()
    lazy var serverValidator: ServerConfigValidator = ServerConfigValidator()
    lazy var diagnosticsService: DiagnosticsService = DiagnosticsService()

    // MARK: - Configure API
    func configureAPI(baseURL: String, token: String) {
        _apiClient = AudiobookshelfClient(baseURL: baseURL, authToken: token)
        isConfigured = true
        
        // Reset ViewModels bei neuer Konfiguration
        resetViewModels()
        
        AppLogger.general.info("[Container] API configured for \(baseURL)")
    }

    // MARK: - Repositories (Safe with Fallback)
    var bookRepository: BookRepository {
        if let existing = _bookRepository { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] BookRepository accessed before API configuration")
            return BookRepository.placeholder
        }
        
        let repo = BookRepository(api: api)
        _bookRepository = repo
        return repo
    }

    var libraryRepository: LibraryRepository {
        if let existing = _libraryRepository { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] LibraryRepository accessed before API configuration")
            return LibraryRepository.placeholder
        }
        
        let repo = LibraryRepository(api: api, settingsRepository: SettingsRepository())
        _libraryRepository = repo
        return repo
    }

    var downloadRepository: DownloadRepository {
        if let existing = _downloadRepository { return existing }
        
        guard let repo = downloadManager.repository else {
            AppLogger.general.error("[Container] DownloadRepository not initialized - DownloadManager.repository is nil")
            fatalError("DownloadRepository not available. Ensure DownloadManager is properly initialized before accessing downloadRepository.")
        }
        
        _downloadRepository = repo
        return repo
    }

    // MARK: - ViewModels (Safe Access with Fallback)
    var homeViewModel: HomeViewModel {
        if let existing = _homeViewModel { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] HomeViewModel accessed before API configuration")
            return HomeViewModel.placeholder
        }
        
        let vm = HomeViewModel(
            fetchPersonalizedSectionsUseCase: makeFetchPersonalizedSectionsUseCase(),
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            bookRepository: bookRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            appState: appState,
            onBookSelected: { [weak self] in
                self?.playerStateManager.showPlayerBasedOnSettings()
            }
        )
        
        _homeViewModel = vm
        return vm
    }

    var libraryViewModel: LibraryViewModel {
        if let existing = _libraryViewModel { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] LibraryViewModel accessed before API configuration")
            return LibraryViewModel.placeholder
        }
        
        let vm = LibraryViewModel(
            fetchBooksUseCase: makeFetchBooksUseCase(),
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            appState: appState,
            onBookSelected: { [weak self] in
                self?.playerStateManager.showPlayerBasedOnSettings()
            }
        )
        
        _libraryViewModel = vm
        return vm
    }

    var seriesViewModel: SeriesViewModel {
        if let existing = _seriesViewModel { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] SeriesViewModel accessed before API configuration")
            return SeriesViewModel.placeholder
        }
        
        let vm = SeriesViewModel(
            fetchSeriesUseCase: makeFetchSeriesUseCase(),
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            appState: appState,
            onBookSelected: { }
        )
        
        _seriesViewModel = vm
        return vm
    }

    var authorsViewModel: AuthorsViewModel {
        if let existing = _authorsViewModel { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] AuthorsViewModel accessed before API configuration")
            return AuthorsViewModel.placeholder
        }
        
        let vm = AuthorsViewModel(
            fetchAuthorsUseCase: makeFetchAuthorsUseCase(),
            libraryRepository: libraryRepository,
            api: api
        )
        
        _authorsViewModel = vm
        return vm
    }

    var downloadsViewModel: DownloadsViewModel {
        if let existing = _downloadsViewModel { return existing }
        
        guard let api = _apiClient else {
            AppLogger.general.error("[Container] DownloadsViewModel accessed before API configuration")
            return DownloadsViewModel.placeholder
        }
        
        let vm = DownloadsViewModel(
            downloadManager: downloadManager,
            player: player,
            api: api,
            appState: appState,
            storageMonitor: storageMonitor,
            onBookSelected: { [weak self] in
                self?.playerStateManager.showPlayerBasedOnSettings()
            }
        )
        
        _downloadsViewModel = vm
        return vm
    }

    var settingsViewModel: SettingsViewModel {
        if let existing = _settingsViewModel { return existing }
        
        let vm = SettingsViewModel(
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
            downloadManager: downloadManager,
            settingsRepository: SettingsRepository()
        )
        
        _settingsViewModel = vm
        return vm
    }

    // MARK: - Use Cases
    func makeFetchBooksUseCase() -> FetchBooksUseCase {
        FetchBooksUseCase(bookRepository: bookRepository)
    }

    func makeFetchSeriesUseCase() -> FetchSeriesUseCase {
        FetchSeriesUseCase(bookRepository: bookRepository)
    }

    func makeFetchAuthorsUseCase() -> FetchAuthorsUseCase {
        FetchAuthorsUseCase(bookRepository: bookRepository)
    }
    
    func makeFetchPersonalizedSectionsUseCase() -> FetchPersonalizedSectionsUseCase {
        FetchPersonalizedSectionsUseCase(bookRepository: bookRepository)
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

    // MARK: - Reset Methods
    func resetRepositories() {
        _bookRepository = nil
        _libraryRepository = nil
        _downloadRepository = nil
    }
    
    func resetViewModels() {
        _homeViewModel = nil
        _libraryViewModel = nil
        _seriesViewModel = nil
        _authorsViewModel = nil
        _downloadsViewModel = nil
        // SettingsViewModel wird nicht resettet
    }

    @MainActor
    func reset() {
        AppLogger.general.info("[Container] Factory reset initiated")

        bookRepository.clearCache()
        libraryRepository.clearCache()
        
        resetRepositories()
        resetViewModels()
        
        isConfigured = false
        _apiClient = nil

        AppLogger.general.info("[Container] All repositories and ViewModels reset")
    }
}

// MARK: - Placeholder Extensions
extension BookRepository {
    static var placeholder: BookRepository {
        let dummyClient = AudiobookshelfClient(baseURL: "", authToken: "")
        return BookRepository(api: dummyClient)
    }
}

extension LibraryRepository {
    static var placeholder: LibraryRepository {
        let dummyClient = AudiobookshelfClient(baseURL: "", authToken: "")
        return LibraryRepository(api: dummyClient, settingsRepository: SettingsRepository())
    }
}

// Note: DownloadRepository ist ein Protocol - kein Placeholder möglich
// Stattdessen wird bei fehlendem Repository direkt ein fatalError geworfen

// MARK: - ViewModel Placeholders
extension HomeViewModel {
    static var placeholder: HomeViewModel {
        fatalError("HomeViewModel accessed before API configuration. Check your setup flow.")
    }
}

extension LibraryViewModel {
    static var placeholder: LibraryViewModel {
        fatalError("LibraryViewModel accessed before API configuration. Check your setup flow.")
    }
}

extension SeriesViewModel {
    static var placeholder: SeriesViewModel {
        fatalError("SeriesViewModel accessed before API configuration. Check your setup flow.")
    }
}

extension AuthorsViewModel {
    static var placeholder: AuthorsViewModel {
        fatalError("AuthorsViewModel accessed before API configuration. Check your setup flow.")
    }
}

extension DownloadsViewModel {
    static var placeholder: DownloadsViewModel {
        fatalError("DownloadsViewModel accessed before API configuration. Check your setup flow.")
    }
}
