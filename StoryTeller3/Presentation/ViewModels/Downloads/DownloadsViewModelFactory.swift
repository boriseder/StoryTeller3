import Foundation

struct DownloadsViewModelFactory {
    @MainActor
    static func create(
        container: DependencyContainer,
        onBookSelected: @escaping () -> Void
    ) -> DownloadsViewModel {
        DownloadsViewModel(
            downloadManager: container.downloadManager,
            playBookUseCase: container.playBookUseCase,
            appState: container.appStateManager,
            storageMonitor: container.networkMonitor,
            onBookSelected: onBookSelected
        )
    }
}
