import Foundation

struct SeriesQuickAccessViewModelFactory {
    @MainActor
    static func create(
        seriesBook: Book,
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> SeriesQuickAccessViewModel {
        SeriesQuickAccessViewModel(
            seriesBook: seriesBook,
            fetchSeriesBooksUseCase: container.fetchSeriesBooksUseCase,
            playBookUseCase: container.playBookUseCase,
            coverPreloadUseCase: container.coverPreloadUseCase,
            downloadRepository: container.downloadRepository,
            onBookSelected: onBookSelected
        )
    }
}
