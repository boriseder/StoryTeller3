import Foundation

struct DownloadsViewModelFactory {
    @MainActor
    static func create(
        downloadManager: DownloadManager,
        player: AudioPlayer,
        api: AudiobookshelfClient,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void
    ) -> DownloadsViewModel {
        // Create Use Cases
        let playBookUseCase = PlayBookUseCase(
            api: api,
            player: player,
            downloadManager: downloadManager
        )
        
        return DownloadsViewModel(
            downloadManager: downloadManager,
            playBookUseCase: playBookUseCase,
            appState: appState,
            storageMonitor: StorageMonitor(),
            onBookSelected: onBookSelected
        )
    }
}
