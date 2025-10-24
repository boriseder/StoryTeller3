import Foundation

struct HomeViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> HomeViewModel {
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let fetchPersonalizedSectionsUseCase = FetchPersonalizedSectionsUseCase(bookRepository: bookRepository)
        
        // Access the repository from downloadManager instead of trying to instantiate the protocol
        guard let downloadRepository = downloadManager.repository else {
            fatalError("DownloadManager repository not initialized. Ensure DownloadManager is fully set up before creating ViewModels.")
        }
        
        let libraryRepository = LibraryRepository(api: api)
        
        return HomeViewModel(
            fetchPersonalizedSectionsUseCase: fetchPersonalizedSectionsUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
}
