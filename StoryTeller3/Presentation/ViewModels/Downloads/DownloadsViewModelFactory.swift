import Foundation

struct DownloadsViewModelFactory {
    @MainActor
    static func create(
        downloadManager: DownloadManager,
        player: AudioPlayer,
        onBookSelected: @escaping () -> Void
    ) -> DownloadsViewModel {
        return DownloadsViewModel(
            downloadManager: downloadManager,
            player: player,
            storageMonitor: StorageMonitor(),
            onBookSelected: onBookSelected
        )
    }
}
