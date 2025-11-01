import Foundation

struct HomeViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfClient,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void,
        container: DependencyContainer = .shared
    ) -> HomeViewModel {
        return HomeViewModel(
            fetchPersonalizedSectionsUseCase: container.makeFetchPersonalizedSectionsUseCase(api: api),
            downloadRepository: container.makeDownloadRepository(),
            libraryRepository: container.makeLibraryRepository(api: api),
            api: api,
            downloadManager: container.downloadManager,
            player: container.player,
            appState: appState,
            onBookSelected: onBookSelected
        )
    }
}
