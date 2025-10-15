import Foundation

struct SeriesViewModelFactory {
    @MainActor
    static func create(
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> SeriesViewModel {
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let fetchSeriesUseCase = FetchSeriesUseCase(bookRepository: bookRepository)
        let downloadRepository = DownloadRepository(downloadManager: downloadManager)
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
