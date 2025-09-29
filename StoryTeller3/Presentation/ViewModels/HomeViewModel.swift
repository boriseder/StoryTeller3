//
//  Enhanced HomeViewModel.swift
//  StoryTeller3
//

import SwiftUI

class HomeViewModel: BaseViewModel {
    @Published var personalizedSections: [PersonalizedSection] = []
    @Published var libraryName: String = "Personalized"
    @Published var libraries: [Library] = []

    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
    // Computed properties for stats
    var totalItemsCount: Int {
        personalizedSections.reduce(0) { total, section in
            total + section.entities.count
        }
    }
    
    var downloadedCount: Int {
        let allBooks = getAllBooksFromSections()
        return allBooks.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    init(api: AudiobookshelfAPI, player: AudioPlayer, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        super.init()
    }
    
    // MARK: - Public Methods
    
    func loadPersonalizedSectionsIfNeeded() async {
        if personalizedSections.isEmpty {
            await loadPersonalizedSections()
        }
    }
    
    @MainActor
    func loadPersonalizedSections() async {
        isLoading = true
        resetError()
        
        do {
            // Use cached libraries if available, otherwise fetch them
            let availableLibraries: [Library]
            if libraries.isEmpty {
                availableLibraries = try await api.fetchLibraries()
                libraries = availableLibraries
            } else {
                availableLibraries = libraries
            }
            
            let selectedLibrary: Library
            if let savedId = UserDefaults.standard.string(forKey: "selected_library_id"),
               let found = availableLibraries.first(where: { $0.id == savedId }) {
                selectedLibrary = found
            } else if let first = availableLibraries.first {
                selectedLibrary = first
                UserDefaults.standard.set(first.id, forKey: "selected_library_id")
            } else {
                libraryName = "Personalized"
                personalizedSections = []
                isLoading = false
                return
            }

            libraryName = "\(selectedLibrary.name) - Home"
            let fetchedSections = try await api.fetchPersonalizedSections(from: selectedLibrary.id)
            
            withAnimation(.easeInOut) {
                personalizedSections = fetchedSections
            }
            
            if !getAllBooksFromSections().isEmpty {
                CoverCacheManager.shared.preloadCovers(
                    for: Array(getAllBooksFromSections().prefix(10)),
                    api: api,
                    downloadManager: downloadManager
                )
            }
            
        } catch {
            handleError(error)
            AppLogger.debug.debug("Error loading personalized sections: \(error)")
        }
        
        isLoading = false
    }

    @MainActor
    func loadAndPlayBook(_ book: Book, restoreState: Bool = true) async {
        AppLogger.debug.debug("Loading book from recommendations: \(book.title), restoreState: \(restoreState)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            
            let isOffline = downloadManager.isBookDownloaded(fetchedBook.id)
            player.load(book: fetchedBook, isOffline: isOffline, restoreState: restoreState)
            
            onBookSelected()
            AppLogger.debug.debug("Book '\(fetchedBook.title)' loaded from recommendations")
        } catch {
            errorMessage = "Could not load '\(book.title)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Error loading book details from recommendations: \(error)")
        }
    }

    @MainActor
    func loadSeriesBooks(_ series: Series) async {
        AppLogger.debug.debug("Loading series: \(series.name)")
        
        do {
            // Get library ID
            guard let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") else {
                throw AudiobookshelfError.noLibrarySelected
            }
            
            // Fetch series books
            let seriesBooks = try await api.fetchSeriesSingle(from: libraryId, seriesId: series.id)
            
            // For now, just play the first book in the series
            // In a real app, you might want to show a sheet with all books
            if let firstBook = seriesBooks.first {
                await loadAndPlayBook(firstBook)
            }
            
        } catch {
            errorMessage = "Could not load series '\(series.name)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Error loading series: \(error)")
        }
    }
    
    @MainActor
    func searchBooksByAuthor(_ authorName: String) async {
        AppLogger.debug.debug("Searching books by author: \(authorName)")
        
        do {
            // Get library ID
            guard let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") else {
                throw AudiobookshelfError.noLibrarySelected
            }
            
            // Fetch all books and filter by author
            let allBooks = try await api.fetchBooks(from: libraryId, limit: 0, collapseSeries: false)
            let authorBooks = allBooks.filter { book in
                book.author?.localizedCaseInsensitiveContains(authorName) == true
            }
            
            // For now, just play the first book by this author
            // In a real app, you might want to show a sheet with all books by this author
            if let firstBook = authorBooks.first {
                await loadAndPlayBook(firstBook)
            } else {
                errorMessage = "No books found by '\(authorName)'"
                showingErrorAlert = true
            }
            
        } catch {
            errorMessage = "Could not search books by '\(authorName)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Error searching books by author: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getAllBooksFromSections() -> [Book] {
        var allBooks: [Book] = []
        
        for section in personalizedSections {
            let sectionBooks = section.entities
                .compactMap { $0.asLibraryItem }
                .compactMap { api.convertLibraryItemToBook($0) }
            
            allBooks.append(contentsOf: sectionBooks)
        }
        
        return allBooks
    }
}

// MARK: - UI State Extension
extension HomeViewModel {
    var uiState: HomeUIState {
        if isLoading {
            return .loading
        } else if let error = errorMessage {
            return .error(error)
        } else if personalizedSections.isEmpty {
            return .empty
        } else {
            return .content
        }
    }
}
