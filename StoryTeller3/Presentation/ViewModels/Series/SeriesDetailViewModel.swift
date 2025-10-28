//
//  SeriesDetailViewModel.swift
//  StoryTeller3
//
//  Clean Architecture: ViewModel with UseCases only

import SwiftUI

@MainActor
class SeriesDetailViewModel: ObservableObject {
    // MARK: - Published State
    @Published var seriesBooks: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    // MARK: - Dependencies (UseCases & Repositories ONLY)
    private let series: Series
    private let fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol
    private let playBookUseCase: PlayBookUseCaseProtocol
    private let coverPreloadUseCase: CoverPreloadUseCaseProtocol
    private let downloadRepository: DownloadRepository
    private let onBookSelected: () -> Void
    
    // MARK: - Computed Properties
    var downloadedCount: Int {
        seriesBooks.filter { downloadRepository.getDownloadStatus(for: $0.id).isDownloaded }.count
    }
    
    // MARK: - Init
    init(
        series: Series,
        fetchSeriesBooksUseCase: FetchSeriesBooksUseCaseProtocol,
        playBookUseCase: PlayBookUseCaseProtocol,
        coverPreloadUseCase: CoverPreloadUseCaseProtocol,
        downloadRepository: DownloadRepository,
        onBookSelected: @escaping () -> Void
    ) {
        self.series = series
        self.fetchSeriesBooksUseCase = fetchSeriesBooksUseCase
        self.playBookUseCase = playBookUseCase
        self.coverPreloadUseCase = coverPreloadUseCase
        self.downloadRepository = downloadRepository
        self.onBookSelected = onBookSelected
    }
    
    // MARK: - Actions
    func loadSeriesBooks() async {
        guard let libraryId = LibraryHelpers.getCurrentLibraryId() else {
            errorMessage = "No library selected"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let books = try await fetchSeriesBooksUseCase.execute(
                libraryId: libraryId,
                seriesId: series.id
            )
            
            withAnimation(.easeInOut(duration: 0.3)) {
                seriesBooks = books
            }
            
            // Preload covers
            await coverPreloadUseCase.execute(books: books, limit: 10)
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.error("[SeriesDetailVM] Error loading books: \(error)")
        }
        
        isLoading = false
    }
    
    func playBook(_ book: Book, appState: AppStateManager) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await playBookUseCase.execute(
                book: book,
                appState: appState,
                restoreState: true
            )
            onBookSelected()
            
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.general.error("[SeriesDetailVM] Failed to play book: \(error)")
        }
        
        isLoading = false
    }
    
    func downloadBook(_ book: Book) async {
        // Delegate to DownloadRepository
        // Note: This might need a DownloadBookUseCase if logic gets complex
        // For now, repository is acceptable as it's a simple data operation
    }
    
    func deleteBook(_ bookId: String) {
        downloadRepository.deleteBook(bookId)
    }
    
    func isBookDownloaded(_ bookId: String) -> Bool {
        downloadRepository.getDownloadStatus(for: bookId).isDownloaded
    }
}
