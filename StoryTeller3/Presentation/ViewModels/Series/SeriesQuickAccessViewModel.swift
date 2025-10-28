import SwiftUI

@MainActor
class SeriesQuickAccessViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var seriesBooks: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    // MARK: - Public Properties (for View access only)
    let seriesBook: Book
    let onBookSelected: () -> Void
    var onDismiss: (() -> Void)?
    
    // MARK: - Dependencies (UseCases & Repositories ONLY)
    private let fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol
    private let playBookUseCase: PlayBookUseCaseProtocol
    private let coverPreloadUseCase: CoverPreloadUseCaseProtocol
    private let downloadRepository: DownloadRepository
    
    // MARK: - Computed Properties
    var downloadedCount: Int {
        seriesBooks.filter { downloadRepository.getDownloadStatus(for: $0.id).isDownloaded }.count
    }
    
    // MARK: - Init with DI
    init(
        seriesBook: Book,
        fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol,
        playBookUseCase: PlayBookUseCaseProtocol,
        coverPreloadUseCase: CoverPreloadUseCaseProtocol,
        downloadRepository: DownloadRepository,
        onBookSelected: @escaping () -> Void
    ) {
        self.seriesBook = seriesBook
        self.fetchSeriesBooksUseCase = fetchSeriesBooksUseCase
        self.playBookUseCase = playBookUseCase
        self.coverPreloadUseCase = coverPreloadUseCase
        self.downloadRepository = downloadRepository
        self.onBookSelected = onBookSelected
    }
    
    // MARK: - Actions
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
            // ✅ CORRECT: libraryId is required parameter
            let books = try await fetchSeriesBooksUseCase.execute(
                libraryId: libraryId,
                seriesId: seriesId
            )
            
            withAnimation(.easeInOut(duration: 0.3)) {
                seriesBooks = books
            }
            
            // ✅ CORRECT: execute method name
            await coverPreloadUseCase.execute(books: books, limit: 10)
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.error("[SeriesQuickAccessVM] Load error: \(error)")
        }
        
        isLoading = false
    }
    
    func playBook(_ book: Book, appState: AppStateManager) async {
        isLoading = true
        
        do {
            try await playBookUseCase.execute(
                book: book,
                appState: appState,
                restoreState: true
            )
            onDismiss?()
            onBookSelected()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.error("[SeriesQuickAccessVM] Play error: \(error)")
        }
        
        isLoading = false
    }
}
