import Foundation

struct HomeViewModelFactory {
    @MainActor
    static func create(
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> HomeViewModel {
        HomeViewModel(
            fetchPersonalizedSectionsUseCase: container.fetchPersonalizedSectionsUseCase,
            fetchLibraryStatsUseCase: container.fetchLibraryStatsUseCase,
            fetchSeriesBooksUseCase: container.fetchSeriesBooksUseCase,
            searchBooksByAuthorUseCase: container.searchBooksByAuthorUseCase,
            playBookUseCase: container.playBookUseCase,
            coverPreloadUseCase: container.coverPreloadUseCase,
            convertLibraryItemUseCase: container.convertLibraryItemUseCase,
            downloadRepository: container.downloadRepository,
            libraryRepository: container.libraryRepository,
            onBookSelected: onBookSelected
        )
    }
}
