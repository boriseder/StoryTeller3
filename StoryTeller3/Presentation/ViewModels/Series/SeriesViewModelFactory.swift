import Foundation

struct SeriesViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfClient,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void,
        container: DependencyContainer? = nil
    ) -> SeriesViewModel {
        let container = container ?? DependencyContainer.shared
        let fetchSeriesUseCase = container.makeFetchSeriesUseCase(api: api)
        let downloadRepository = container.makeDownloadRepository()
        let libraryRepository = container.makeLibraryRepository(api: api)
        
        return SeriesViewModel(
            fetchSeriesUseCase: fetchSeriesUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: container.downloadManager,
            player: container.player,
            appState: appState,
            onBookSelected: onBookSelected
        )
    }
}
