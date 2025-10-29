import Foundation

struct HomeViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfClient,
        onBookSelected: @escaping () -> Void,
        container: DependencyContainer? = nil
    ) -> HomeViewModel {
        let container = container ?? DependencyContainer.shared
        let fetchPersonalizedSectionsUseCase = container.makeFetchPersonalizedSectionsUseCase(api: api)
        let downloadRepository = container.makeDownloadRepository()
        let libraryRepository = container.makeLibraryRepository(api: api)
        
        return HomeViewModel(
            fetchPersonalizedSectionsUseCase: fetchPersonalizedSectionsUseCase,
            downloadRepository: downloadRepository,
            libraryRepository: libraryRepository,
            api: api,
            downloadManager: container.downloadManager,
            player: container.player,
            onBookSelected: onBookSelected
        )
    }
}
