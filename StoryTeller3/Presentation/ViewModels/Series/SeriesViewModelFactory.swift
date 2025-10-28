import Foundation

struct SeriesViewModelFactory {
    @MainActor
    static func create(
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> SeriesViewModel {
        // Create Repositories
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let libraryRepository = LibraryRepository(api: api)
        
        guard let downloadRepository = downloadManager.repository else {
            fatalError("DownloadManager repository not initialized")
        }
        
        // Create Use Cases
        let fetchSeriesUseCase = FetchSeriesUseCase(bookRepository: bookRepository)
        let playBookUseCase = PlayBookUseCase(
            api: api,
            player: player,
            downloadManager: downloadManager
        )
        let convertLibraryItemUseCase = ConvertLibraryItemUseCase(converter: api.converter)
        
        return SeriesViewModel(
            fetchSeriesUseCase: fetchSeriesUseCase,
            playBookUseCase: playBookUseCase,
            convertLibraryItemUseCase: convertLibraryItemUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            onBookSelected: onBookSelected
        )
    }
}
