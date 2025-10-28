import Foundation

struct SeriesViewModelFactory {
    @MainActor
    static func create(
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> SeriesViewModel {
        SeriesViewModel(
            fetchSeriesUseCase: container.fetchSeriesUseCase,
            playBookUseCase: container.playBookUseCase,
            convertLibraryItemUseCase: container.convertLibraryItemUseCase,
            downloadRepository: container.downloadRepository,
            libraryRepository: container.libraryRepository,
            onBookSelected: onBookSelected
        )
    }
}
