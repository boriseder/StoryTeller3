import SwiftUI

@MainActor
class SeriesSectionViewModel: ObservableObject {
    let series: Series
    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    private let playBookUseCase: PlayBookUseCase
    
    var books: [Book] {
        series.books.compactMap { api.convertLibraryItemToBook($0) }
    }
    
    init(
        series: Series,
        api: AudiobookshelfAPI,
        player: AudioPlayer,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        self.series = series
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        self.playBookUseCase = PlayBookUseCase()
    }
    
    func playBook(_ book: Book, appState: AppStateManager) async {
        do {
            try await playBookUseCase.execute(
                book: book,
                api: api,
                player: player,
                downloadManager: downloadManager,
                appState: appState,
                restoreState: true
            )
            onBookSelected()
        } catch {
            AppLogger.debug.debug("[SeriesSectionViewModel] Failed to play book: \(error)")
        }
    }
}
