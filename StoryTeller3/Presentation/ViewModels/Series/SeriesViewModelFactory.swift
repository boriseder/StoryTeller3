import Foundation

struct SeriesViewModelFactory {
    @MainActor
    static func create(
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> SeriesViewModel {
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let fetchSeriesUseCase = FetchSeriesUseCase(bookRepository: bookRepository)

        guard let downloadRepository = downloadManager.repository else {
            fatalError("DownloadManager repository not initialized")
        }

        let libraryRepository = LibraryRepository(api: api)
        
        return SeriesViewModel(
            fetchSeriesUseCase: fetchSeriesUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: downloadManager,
            player: player,
            onBookSelected: onBookSelected
        )
    }
}
