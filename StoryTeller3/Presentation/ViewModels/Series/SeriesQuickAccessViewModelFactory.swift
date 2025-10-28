//
//  SeriesQuickAccessViewModelFactory.swift
//  StoryTeller3
//

import Foundation

struct SeriesQuickAccessViewModelFactory {
    @MainActor
    static func create(
        seriesBook: Book,
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> SeriesQuickAccessViewModel {
        // Create Repositories
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let downloadRepository = downloadManager.repository!
        
        // Create Use Cases
        let fetchSeriesBooksUseCase = FetchSeriesBooksUseCase(
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
        
        return SeriesQuickAccessViewModel(
            seriesBook: seriesBook,
            fetchSeriesBooksUseCase: fetchSeriesBooksUseCase,
            playBookUseCase: playBookUseCase,
            coverPreloadUseCase: coverPreloadUseCase,
            downloadRepository: downloadRepository,
            onBookSelected: onBookSelected
        )
    }
}
