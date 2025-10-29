import Foundation

struct LibraryViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfClient,
        onBookSelected: @escaping () -> Void,
        container: DependencyContainer? = nil
    ) -> LibraryViewModel {
        let container = container ?? DependencyContainer.shared
        let fetchBooksUseCase = container.makeFetchBooksUseCase(api: api)
        let downloadRepository = container.makeDownloadRepository()
        let libraryRepository = container.makeLibraryRepository(api: api)
        
        return LibraryViewModel(
            fetchBooksUseCase: fetchBooksUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: container.downloadManager,
            player: container.player,
            onBookSelected: onBookSelected
        )
    }
}
