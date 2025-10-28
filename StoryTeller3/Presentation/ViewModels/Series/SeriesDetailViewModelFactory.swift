import Foundation

@MainActor
struct SeriesDetailViewModelFactory {
    static func create(
        series: Series,
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> SeriesDetailViewModel {
        SeriesDetailViewModel(
            series: series,
            fetchSeriesBooksUseCase: container.fetchSeriesBooksUseCase,
            playBookUseCase: container.playBookUseCase,
            coverPreloadUseCase: container.coverPreloadUseCase,
            downloadRepository: container.downloadRepository,
            onBookSelected: onBookSelected
        )
    }
}
