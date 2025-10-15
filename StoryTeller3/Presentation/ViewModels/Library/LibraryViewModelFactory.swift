import Foundation

struct LibraryViewModelFactory {
    @MainActor
    static func create(
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> LibraryViewModel {
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let fetchBooksUseCase = FetchBooksUseCase(bookRepository: bookRepository)
        let downloadRepository = DownloadRepository(downloadManager: downloadManager)
        let libraryRepository = LibraryRepository(api: api)
        
        return LibraryViewModel(
            fetchBooksUseCase: fetchBooksUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
}
