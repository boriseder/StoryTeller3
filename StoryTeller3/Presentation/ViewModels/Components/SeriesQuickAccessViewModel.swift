import SwiftUI

@MainActor
class SeriesQuickAccessViewModel: ObservableObject {
    @Published var seriesBooks: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    let seriesBook: Book
    let player: AudioPlayer
    let api: AudiobookshelfClient
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    var onDismiss: (() -> Void)?
    
    private let fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol
    private let playBookUseCase: PlayBookUseCase
    
    var downloadedCount: Int {
        seriesBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    init(
        seriesBook: Book,
        player: AudioPlayer,
        api: AudiobookshelfClient,
        downloadManager: DownloadManager,
        onBookSelected: @escaping () -> Void
    ) {
        self.seriesBook = seriesBook
        self.player = player
        self.api = api
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        self.fetchSeriesBooksUseCase = FetchSeriesBooksUseCase(api: api)
        self.playBookUseCase = PlayBookUseCase()
    }
    
    func loadSeriesBooks() async {
        guard let seriesId = seriesBook.collapsedSeries?.id,
              let libraryId = LibraryHelpers.getCurrentLibraryId() else {
            errorMessage = "Serie oder Bibliothek nicht gefunden"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        showingErrorAlert = false
        
        do {
            let books = try await fetchSeriesBooksUseCase.execute(
                libraryId: libraryId,
                seriesId: seriesId
            )
            
            withAnimation(.easeInOut(duration: 0.3)) {
                seriesBooks = books
            }
            
            CoverPreloadHelpers.preloadIfNeeded(
                books: books,
                api: api,
                downloadManager: downloadManager
            )
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
    
    func playBook(_ book: Book, appState: AppStateManager) async {
        isLoading = true
        
        do {
            try await playBookUseCase.execute(
                book: book,
                api: api,
                player: player,
                downloadManager: downloadManager,
                appState: appState,
                restoreState: true
            )
            onDismiss?()
            onBookSelected()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
}
