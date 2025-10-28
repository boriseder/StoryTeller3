import Foundation

@MainActor
struct AuthorDetailViewModelFactory {
    static func create(
        authorName: String,
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> AuthorDetailViewModel {
        AuthorDetailViewModel(
            authorName: authorName,
            searchBooksByAuthorUseCase: container.searchBooksByAuthorUseCase,
            playBookUseCase: container.playBookUseCase,
            coverPreloadUseCase: container.coverPreloadUseCase,
            downloadRepository: container.downloadRepository,
            onBookSelected: onBookSelected
        )
    }
}
