import SwiftUI

class LibraryViewModel: BaseViewModel {
    @Published var books: [Book] = []
    @Published var searchText = ""
    @Published var selectedSortOption: LibrarySortOption = .title
    @Published var showDownloadedOnly = false
    @Published var showSeriesGrouped = false
    @Published var libraryName: String = "Meine Bibliothek"
    
    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
     let onBookSelected: () -> Void
    
    var filteredAndSortedBooks: [Book] {
        let filtered = searchText.isEmpty ? books : books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }

        let downloadFiltered = showDownloadedOnly ? filtered.filter { book in
            downloadManager.isBookDownloaded(book.id)
        } : filtered

        return downloadFiltered.sorted { book1, book2 in
            switch selectedSortOption {
            case .title:
                return book1.title.localizedCompare(book2.title) == .orderedAscending
            case .author:
                return (book1.author ?? "Unbekannt").localizedCompare(book2.author ?? "Unbekannt") == .orderedAscending
            case .recent:
                return book1.id > book2.id
            }
        }
    }
    
    var downloadedBooksCount: Int {
        books.filter { downloadManager.isBookDownloaded($0.id) }.count
    }
    
    var totalBooksCount: Int {
        books.count
    }
    
    var seriesCount: Int {
        books.filter { $0.isCollapsedSeries }.count
    }
    
    var individualBooksCount: Int {
        books.filter { !$0.isCollapsedSeries }.count
    }
    
    init(api: AudiobookshelfAPI, player: AudioPlayer, downloadManager: DownloadManager, onBookSelected: @escaping () -> Void) {
        self.api = api
        self.player = player
        self.downloadManager = downloadManager
        self.onBookSelected = onBookSelected
        super.init()
        
        loadFilterSettings()
        
    }
    
    func loadBooksIfNeeded() async {
        if books.isEmpty {
            await loadBooks()
        }
    }
    
    @MainActor
    func loadBooks() async {
        isLoading = true
        resetError()
        
        do {
            let fetchedBooks: [Book]
            
            if let libraryId = UserDefaults.standard.string(forKey: "selected_library_id") {
                let libraries = try await api.fetchLibraries()
                if let selectedLibrary = libraries.first(where: { $0.id == libraryId }) {
                    libraryName = selectedLibrary.name
                                        
                    fetchedBooks = try await api.fetchBooks(from: libraryId, limit: 0, collapseSeries: showSeriesGrouped)
                    
                    _ = showSeriesGrouped ? "gebündelt" : "einzeln"
                    
                } else {
                    throw AudiobookshelfError.libraryNotFound("Selected library not found")
                }
            } else {
                let libraries = try await api.fetchLibraries()
                if let firstLibrary = libraries.first {
                    libraryName = firstLibrary.name
                                        
                    fetchedBooks = try await api.fetchBooks(from: firstLibrary.id, limit: 0, collapseSeries: showSeriesGrouped)
                    
                    UserDefaults.standard.set(firstLibrary.id, forKey: "selected_library_id")
                } else {
                    libraryName = "Keine Bibliothek"
                    fetchedBooks = []
                }
            }
            
            withAnimation(.easeInOut) {
                books = fetchedBooks
            }
            
            if !fetchedBooks.isEmpty {
                CoverCacheManager.shared.preloadCovers(
                    for: Array(fetchedBooks.prefix(10)),
                    api: api,
                    downloadManager: downloadManager
                )
            }
            
        } catch {
            handleError(error)
            AppLogger.debug.debug("Fehler beim Laden der Bücher: \(error)")
        }
        
        isLoading = false
    }
        
    @MainActor
    func loadAndPlayBook(_ book: Book) async {
        AppLogger.debug.debug("Lade Buch: \(book.title)")
        
        do {
            let fetchedBook = try await api.fetchBookDetails(bookId: book.id)
            player.configure(baseURL: api.baseURLString, authToken: api.authToken, downloadManager: downloadManager)
            player.load(book: fetchedBook)
            onBookSelected()
            AppLogger.debug.debug("Buch '\(fetchedBook.title)' geladen")
            AppLogger.debug.debug("Buch von '\(fetchedBook.author ?? "Unbekannt")'")

        } catch {
            errorMessage = "Konnte '\(book.title)' nicht laden: \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Fehler beim Laden der Buchdetails: \(error)")
        }
    }
    
    // MARK: - Series Toggle Funktionen
    
    func toggleSeriesMode() {
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showSeriesGrouped.toggle()
        }
        
        saveFilterSettings()
        
        // Reload data with new mode
        Task {
            await loadBooks()
        }
    }
    
    func toggleDownloadFilter() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDownloadedOnly.toggle()
        }
        saveFilterSettings()
    }
    
    private func loadFilterSettings() {
        showDownloadedOnly = UserDefaults.standard.bool(forKey: "library_show_downloaded_only")
        showSeriesGrouped = UserDefaults.standard.bool(forKey: "library_show_series_grouped")
    }
    
    private func saveFilterSettings() {
        UserDefaults.standard.set(showDownloadedOnly, forKey: "library_show_downloaded_only")
        UserDefaults.standard.set(showSeriesGrouped, forKey: "library_show_series_grouped")
    }
    
    func resetFilters() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDownloadedOnly = false
            showSeriesGrouped = false
            searchText = ""
        }
        saveFilterSettings()
        
        Task {
            await loadBooks()
        }
    }
}
