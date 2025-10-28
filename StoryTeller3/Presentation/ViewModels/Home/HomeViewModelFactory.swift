import Foundation

struct HomeViewModelFactory {
    @MainActor
    static func create(
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> HomeViewModel {
        // Create Repositories
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let libraryRepository = LibraryRepository(api: api)
        
        guard let downloadRepository = downloadManager.repository else {
            fatalError("DownloadManager repository not initialized. Ensure DownloadManager is fully set up before creating ViewModels.")
        }
        
        // Create Use Cases
        let fetchPersonalizedSectionsUseCase = FetchPersonalizedSectionsUseCase(
            bookRepository: bookRepository
        )
        let fetchLibraryStatsUseCase = FetchLibraryStatsUseCase(api: api)
        let fetchSeriesBooksUseCase = FetchSeriesBooksUseCase(
            bookRepository: bookRepository
        )
        let searchBooksByAuthorUseCase = SearchBooksByAuthorUseCase(
            bookRepository: bookRepository
        )
        let playBookUseCase = PlayBookUseCase(
            api: api,
            player: player,
            downloadManager: downloadManager
        )
        let coverPreloadUseCase = CoverPreloadUseCase(
            api: api,
            downloadManager: downloadManager
        )
        let convertLibraryItemUseCase = ConvertLibraryItemUseCase(
            converter: api.converter
        )
        
        return HomeViewModel(
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
}
