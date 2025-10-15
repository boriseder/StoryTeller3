import Foundation

@MainActor
class ViewModelFactory {
    
    // MARK: - Shared Dependencies
    private let api: AudiobookshelfAPI
    private let downloadManager: DownloadManager
    private let player: AudioPlayer
    
    // MARK: - Repositories
    private lazy var bookRepository: BookRepositoryProtocol = {
        BookRepository(api: api, cache: BookCache())
    }()
    
    private lazy var downloadRepository: DownloadRepositoryProtocol = {
        DownloadRepository(downloadManager: downloadManager)
    }()
    
    private lazy var libraryRepository: LibraryRepositoryProtocol = {
        LibraryRepository(api: api)
    }()
    
    // MARK: - Use Cases
    private lazy var fetchBooksUseCase: FetchBooksUseCaseProtocol = {
        FetchBooksUseCase(bookRepository: bookRepository)
    }()
    
    private lazy var fetchPersonalizedSectionsUseCase: FetchPersonalizedSectionsUseCaseProtocol = {
        FetchPersonalizedSectionsUseCase(bookRepository: bookRepository)
    }()
    
    private lazy var fetchSeriesUseCase: FetchSeriesUseCaseProtocol = {
        FetchSeriesUseCase(bookRepository: bookRepository)
    }()
    
    // MARK: - Initialization
    
    init(api: AudiobookshelfAPI, downloadManager: DownloadManager, player: AudioPlayer) {
        self.api = api
        self.downloadManager = downloadManager
        self.player = player
    }
    
    // MARK: - ViewModel Factories
    
    func makeLibraryViewModel(onBookSelected: @escaping () -> Void) -> LibraryViewModel {
        LibraryViewModel(
            fetchBooksUseCase: fetchBooksUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
    
    func makeHomeViewModel(onBookSelected: @escaping () -> Void) -> HomeViewModel {
        HomeViewModel(
            fetchPersonalizedSectionsUseCase: fetchPersonalizedSectionsUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
    
    func makeSeriesViewModel(onBookSelected: @escaping () -> Void) -> SeriesViewModel {
        SeriesViewModel(
            fetchSeriesUseCase: fetchSeriesUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
    
    func makeDownloadsViewModel(onBookSelected: @escaping () -> Void) -> DownloadsViewModel {
        DownloadsViewModel(
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
    
    func makePlayerViewModel() -> PlayerViewModel {
        PlayerViewModel(
            player: player,
            api: api
        )
    }
    
    func makeSleepTimerViewModel() -> SleepTimerViewModel {
        SleepTimerViewModel(player: player)
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel()
    }
}
