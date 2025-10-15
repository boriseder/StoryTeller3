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
        let downloadRepository = DownloadRepository(downloadManager: downloadManager)
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
