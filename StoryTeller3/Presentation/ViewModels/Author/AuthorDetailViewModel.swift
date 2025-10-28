//
//  AuthorDetailViewModel.swift
//  StoryTeller3
//
//  Clean Architecture: ViewModel with UseCases only

import SwiftUI

@MainActor
class AuthorDetailViewModel: ObservableObject {
    // MARK: - Published State
    @Published var authorBooks: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    // MARK: - Public Properties
    let authorName: String
    
    // MARK: - Dependencies (UseCases & Repositories ONLY)
    private let searchBooksByAuthorUseCase: SearchBooksByAuthorUseCaseProtocol
    private let playBookUseCase: PlayBookUseCaseProtocol
    private let coverPreloadUseCase: CoverPreloadUseCaseProtocol
    private let downloadRepository: DownloadRepository
    private let onBookSelected: () -> Void
    
    // MARK: - Computed Properties
    var downloadedCount: Int {
        authorBooks.filter { downloadRepository.getDownloadStatus(for: $0.id).isDownloaded }.count
    }
    
    var totalDuration: Double {
        authorBooks.reduce(0.0) { total, book in
            total + book.chapters.reduce(0.0) { chapterTotal, chapter in
                chapterTotal + ((chapter.end ?? 0) - (chapter.start ?? 0))
            }
        }
    }
    
    // MARK: - Init
    init(
        authorName: String,
        searchBooksByAuthorUseCase: SearchBooksByAuthorUseCaseProtocol,
        playBookUseCase: PlayBookUseCaseProtocol,
        coverPreloadUseCase: CoverPreloadUseCaseProtocol,
        downloadRepository: DownloadRepository,
        onBookSelected: @escaping () -> Void
    ) {
        self.authorName = authorName
        self.searchBooksByAuthorUseCase = searchBooksByAuthorUseCase
        self.playBookUseCase = playBookUseCase
        self.coverPreloadUseCase = coverPreloadUseCase
        self.downloadRepository = downloadRepository
        self.onBookSelected = onBookSelected
    }
    
    // MARK: - Actions
    func loadAuthorBooks() async {
        guard let libraryId = LibraryHelpers.getCurrentLibraryId() else {
            errorMessage = "No library selected"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let books = try await searchBooksByAuthorUseCase.execute(
                libraryId: libraryId,
                authorName: authorName
            )
            
            // Sort by title
            let sortedBooks = books.sorted { book1, book2 in
                book1.title.localizedCompare(book2.title) == .orderedAscending
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                authorBooks = sortedBooks
            }
            
            // Preload covers
            await coverPreloadUseCase.execute(books: sortedBooks, limit: 10)
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.error("[AuthorDetailVM] Error loading books: \(error)")
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
            AppLogger.general.error("[AuthorDetailVM] Failed to play book: \(error)")
        }
        
        isLoading = false
    }
    
    func isBookDownloaded(_ bookId: String) -> Bool {
        downloadRepository.getDownloadStatus(for: bookId).isDownloaded
    }
}
