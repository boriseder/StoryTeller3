import Foundation

@MainActor
class ViewModelFactory {
    
    // MARK: - Dependency Container
    private let container: DependencyContainer
    
    // MARK: - Initialization
    init(container: DependencyContainer) {
        self.container = container
    }
    
    // MARK: - ViewModel Factories
    
    func makeLibraryViewModel(onBookSelected: @escaping () -> Void) -> LibraryViewModel {
        LibraryViewModel(
            fetchBooksUseCase: container.fetchBooksUseCase,
            playBookUseCase: container.playBookUseCase,
            coverPreloadUseCase: container.coverPreloadUseCase,
            downloadRepository: container.downloadRepository,
            libraryRepository: container.libraryRepository,
            onBookSelected: onBookSelected
        )
    }
    
    func makeHomeViewModel(onBookSelected: @escaping () -> Void) -> HomeViewModel {
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
    
    func makeSeriesViewModel(onBookSelected: @escaping () -> Void) -> SeriesViewModel {
        SeriesViewModel(
            fetchSeriesUseCase: container.fetchSeriesUseCase,
            playBookUseCase: container.playBookUseCase,
            convertLibraryItemUseCase: container.convertLibraryItemUseCase,
            downloadRepository: container.downloadRepository,
            libraryRepository: container.libraryRepository,
            onBookSelected: onBookSelected
        )
    }
    
    func makePlayerViewModel() -> PlayerViewModel {
        PlayerViewModel(
            player: container.audioPlayer,
            api: container.audiobookshelfClient
        )
    }
    
    func makeSleepTimerViewModel() -> SleepTimerViewModel {
        SleepTimerViewModel(player: container.audioPlayer)
    }
    
    func makeDownloadsViewModel(onBookSelected: @escaping () -> Void) -> DownloadsViewModel {
        DownloadsViewModel(
            downloadManager: container.downloadManager,
            playBookUseCase: container.playBookUseCase,
            appState: container.appStateManager,
            storageMonitor: container.networkMonitor,
            onBookSelected: onBookSelected
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            testConnectionUseCase: container.testConnectionUseCase,
            authenticationUseCase: container.authenticationUseCase,
            loadCredentialsUseCase: container.loadCredentialsUseCase,
            saveCredentialsUseCase: container.saveCredentialsUseCase,
            logoutUseCase: container.logoutUseCase,
            calculateStorageUseCase: container.calculateStorageUseCase,
            clearCacheUseCase: container.clearCacheUseCase
        )
    }
}
