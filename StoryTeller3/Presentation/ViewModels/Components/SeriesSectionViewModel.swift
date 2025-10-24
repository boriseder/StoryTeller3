import SwiftUI

@MainActor
class SeriesSectionViewModel: ObservableObject {
    let series: Series
    let api: AudiobookshelfClient
    let player: AudioPlayer
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    private let playBookUseCase: PlayBookUseCase
    
    var books: [Book] {
        series.books.compactMap { api.converter.convertLibraryItemToBook($0) }
    }
    
    init(
        series: Series,
        api: AudiobookshelfClient,
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
            AppLogger.general.debug("[SeriesSectionViewModel] Failed to play book: \(error)")
        }
    }
}
