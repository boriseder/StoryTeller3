import Foundation

struct DownloadsViewModelFactory {
    @MainActor
    static func create(
        downloadManager: DownloadManager,
        player: AudioPlayer,
        api: AudiobookshelfAPI,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void
    ) -> DownloadsViewModel {
        return DownloadsViewModel(
            downloadManager: downloadManager,
            player: player,
            api: api,
            appState: appState,
            storageMonitor: StorageMonitor(),
            onBookSelected: onBookSelected
        )
    }
}
