//
//  AuthorDetailViewModel.swift
//  StoryTeller3
//
//  Created by Boris Eder on 08.11.25.
//


import SwiftUI

@MainActor
class AuthorDetailViewModel: ObservableObject {
    @Published var authorBooks: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    let authorName: String
    let onBookSelected: () -> Void
    var onDismiss: (() -> Void)?
    
    private let container: DependencyContainer
    
    var player: AudioPlayer { container.player }
    var api: AudiobookshelfClient { container.apiClient! }
    var downloadManager: DownloadManager { container.downloadManager }
    
    var downloadedCount: Int {
        authorBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    var totalDuration: Double {
        authorBooks.reduce(0.0) { total, book in
            total + (book.chapters.reduce(0.0) { chapterTotal, chapter in
                chapterTotal + ((chapter.end ?? 0) - (chapter.start ?? 0))
            })
        }
    }
    
    private let playBookUseCase: PlayBookUseCase
    
    init(
        authorName: String,
        container: DependencyContainer = .shared,
        onBookSelected: @escaping () -> Void
    ) {
        self.authorName = authorName
        self.container = container
        self.onBookSelected = onBookSelected
        self.playBookUseCase = PlayBookUseCase()
    }
    
    func loadAuthorBooks() async {
        guard let libraryId = LibraryHelpers.getCurrentLibraryId() else {
            errorMessage = "No library selected"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        showingErrorAlert = false
        
        do {
            let allBooks = try await api.books.fetchBooks(libraryId: libraryId, limit: 0, collapseSeries: false)
            let filteredBooks = allBooks.filter { book in
                book.author?.localizedCaseInsensitiveContains(authorName) == true
            }
            
            let sortedBooks = filteredBooks.sorted { book1, book2 in
                book1.title.localizedCompare(book2.title) == .orderedAscending
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                authorBooks = sortedBooks
            }
            
            CoverPreloadHelpers.preloadIfNeeded(
                books: sortedBooks,
                api: api,
                downloadManager: downloadManager
            )
            
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            AppLogger.general.debug("Error loading author books: \(error)")
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
    
    func downloadBook(_ book: Book) async {
        await downloadManager.downloadBook(book, api: api)
    }
    
    func deleteBook(_ bookId: String) {
        downloadManager.deleteBook(bookId)
    }
}