import Foundation

struct DownloadsViewModelFactory {
    @MainActor static func create(
        api: AudiobookshelfClient,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void,
        container: DependencyContainer? = nil
    ) -> DownloadsViewModel {
        let container = container ?? DependencyContainer.shared
        return DownloadsViewModel(
            downloadManager: container.downloadManager,
            player: container.player,
            api: api,
            appState: appState,
            storageMonitor: container.storageMonitor,
            onBookSelected: onBookSelected
        )
    }
}
