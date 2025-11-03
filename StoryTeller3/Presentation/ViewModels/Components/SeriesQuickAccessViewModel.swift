import SwiftUI

@MainActor
class SeriesQuickAccessViewModel: ObservableObject {
    @Published var seriesBooks: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    let seriesBook: Book
    let onBookSelected: () -> Void
    var onDismiss: (() -> Void)?
    
    private let container: DependencyContainer
    
    // Computed properties for dependencies
    var player: AudioPlayer { container.player }
    var api: AudiobookshelfClient { container.apiClient! }
    var downloadManager: DownloadManager { container.downloadManager }  

    var downloadedCount: Int {
        seriesBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    private let fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol
    private let playBookUseCase: PlayBookUseCase

    init(
            seriesBook: Book,
            container: DependencyContainer = .shared,
            onBookSelected: @escaping () -> Void
        ) {
            self.seriesBook = seriesBook
            self.container = container
            self.onBookSelected = onBookSelected
            
            // Create use cases with container dependencies
            self.fetchSeriesBooksUseCase = FetchSeriesBooksUseCase(api: container.apiClient!)
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
