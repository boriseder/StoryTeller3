//
//  SeriesDetailViewModelFactory.swift
//  StoryTeller3
//
//  Factory for creating SeriesDetailViewModel with proper dependencies

import Foundation

@MainActor
struct SeriesDetailViewModelFactory {
    static func create(
        series: Series,
        api: AudiobookshelfClient,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) -> SeriesDetailViewModel {
        
        // Create Repositories
        let bookRepository = BookRepository(api: api, cache: BookCache())
        let downloadRepository = downloadManager.repository!
        
        // Create UseCases
        let fetchSeriesBooksUseCase = FetchSeriesBooksUseCase(bookRepository: bookRepository)
        let playBookUseCase = PlayBookUseCase(api: api, player: player, downloadManager: downloadManager)
        let coverPreloadUseCase = CoverPreloadUseCase(api: api, downloadManager: downloadManager)
        
        // Create ViewModel
        return SeriesDetailViewModel(
            series: series,
            fetchSeriesBooksUseCase: fetchSeriesBooksUseCase,
            playBookUseCase: playBookUseCase,
            coverPreloadUseCase: coverPreloadUseCase,
            downloadRepository: downloadRepository,
            onBookSelected: onBookSelected
        )
    }
}
