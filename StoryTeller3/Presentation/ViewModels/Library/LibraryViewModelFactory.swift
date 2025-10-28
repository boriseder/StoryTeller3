import Foundation

struct LibraryViewModelFactory {
    @MainActor
    static func create(
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> LibraryViewModel {
        LibraryViewModel(
            fetchBooksUseCase: container.fetchBooksUseCase,
            playBookUseCase: container.playBookUseCase,
            coverPreloadUseCase: container.coverPreloadUseCase,
            downloadRepository: container.downloadRepository,
            libraryRepository: container.libraryRepository,
            onBookSelected: onBookSelected
        )
    }
}
