import Foundation

@MainActor
class ViewModelFactory {
    
    // MARK: - Shared Dependencies (Infrastructure only)
    private let api: AudiobookshelfClient
    private let downloadManager: DownloadManager
    private let player: AudioPlayer
    
    // MARK: - Repositories
    private lazy var bookRepository: BookRepositoryProtocol = {
        BookRepository(api: api, cache: BookCache())
    }()
    
    private var downloadRepository: DownloadRepository {
        guard let repo = downloadManager.repository else {
            fatalError("DownloadManager repository not initialized. Check initialization order.")
        }
        return repo
    }
    
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
    
    private lazy var fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol = {
        FetchSeriesBooksUseCase(bookRepository: bookRepository)
    }()
    
    private lazy var fetchLibraryStatsUseCase: FetchLibraryStatsUseCaseProtocol = {
        FetchLibraryStatsUseCase(api: api)
    }()
    
    private lazy var searchBooksByAuthorUseCase: SearchBooksByAuthorUseCaseProtocol = {
        SearchBooksByAuthorUseCase(bookRepository: bookRepository)
    }()
    
    private lazy var playBookUseCase: PlayBookUseCaseProtocol = {
        PlayBookUseCase(
            api: api,
            player: player,
            downloadManager: downloadManager
        )
    }()
    
    private lazy var coverPreloadUseCase: CoverPreloadUseCaseProtocol = {
        CoverPreloadUseCase(
            api: api,
            downloadManager: downloadManager
        )
    }()
    
    private lazy var convertLibraryItemUseCase: ConvertLibraryItemUseCaseProtocol = {
        ConvertLibraryItemUseCase(converter: api.converter)
    }()
    
    // MARK: - Initialization
    
    init(api: AudiobookshelfClient, downloadManager: DownloadManager, player: AudioPlayer) {
        self.api = api
        self.downloadManager = downloadManager
        self.player = player
    }
    
    // MARK: - ViewModel Factories
    
    func makeLibraryViewModel(onBookSelected: @escaping () -> Void) -> LibraryViewModel {
        LibraryViewModel(
            fetchBooksUseCase: fetchBooksUseCase,
            playBookUseCase: playBookUseCase,
            coverPreloadUseCase: coverPreloadUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            onBookSelected: onBookSelected
        )
    }
    
    func makeHomeViewModel(onBookSelected: @escaping () -> Void) -> HomeViewModel {
        HomeViewModel(
            fetchPersonalizedSectionsUseCase: fetchPersonalizedSectionsUseCase,
            fetchLibraryStatsUseCase: fetchLibraryStatsUseCase,
            fetchSeriesBooksUseCase: fetchSeriesBooksUseCase,
            searchBooksByAuthorUseCase: searchBooksByAuthorUseCase,
            playBookUseCase: playBookUseCase,
            coverPreloadUseCase: coverPreloadUseCase,
            convertLibraryItemUseCase: convertLibraryItemUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            onBookSelected: onBookSelected
        )
    }
    
    func makeSeriesViewModel(onBookSelected: @escaping () -> Void) -> SeriesViewModel {
        SeriesViewModel(
            fetchSeriesUseCase: fetchSeriesUseCase,
            playBookUseCase: playBookUseCase,
            convertLibraryItemUseCase: convertLibraryItemUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
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
}
