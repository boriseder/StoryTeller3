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
            
            if let libraryId = LibraryHelpers.getCurrentLibraryId() {
                let libraries = try await api.fetchLibraries()
                if let selectedLibrary = libraries.first(where: { $0.id == libraryId }) {
                    libraryName = selectedLibrary.name
                    
                    // CRASH PROTECTION: Try with series grouping first
                    do {
                        fetchedBooks = try await api.fetchBooks(
                            from: libraryId,
                            limit: 0,
                            collapseSeries: showSeriesGrouped
                        )
                        
                        AppLogger.debug.debug("[Library] Loaded \(fetchedBooks.count) books successfully")
                        
                    } catch let decodingError as DecodingError {
                        // Handle malformed data gracefully
                        AppLogger.debug.debug("[Library] ⚠️ Decoding error: \(decodingError)")
                        
                        // Try to get detailed error information
                        let errorDetails = getDecodingErrorDetails(decodingError)
                        AppLogger.debug.debug("[Library] Error details: \(errorDetails)")
                        
                        // Show user-friendly error
                        errorMessage = """
                        Some books couldn't be loaded due to data format issues.
                        
                        This might happen if:
                        • Your server has corrupted metadata
                        • Server version is incompatible
                        • Network connection was interrupted
                        
                        Try: \(errorDetails)
                        """
                        
                        // Fallback: Try without series grouping
                        if showSeriesGrouped {
                            AppLogger.debug.debug("[Library] 🔄 Retrying without series grouping...")
                            
                            do {
                                fetchedBooks = try await api.fetchBooks(
                                    from: libraryId,
                                    limit: 0,
                                    collapseSeries: false
                                )
                                
                                AppLogger.debug.debug("[Library] Fallback successful: \(fetchedBooks.count) books loaded")
                                
                                // Inform user about the workaround
                                errorMessage = """
                                Loaded \(fetchedBooks.count) books successfully.
                                
                                Note: Series grouping was disabled due to data issues.
                                Contact your Audiobookshelf admin to check server logs.
                                """
                                showingErrorAlert = true
                                
                            } catch {
                                // Even fallback failed - load what we can
                                AppLogger.debug.debug("[Library] ❌ Fallback also failed: \(error)")
                                throw error
                            }
                        } else {
                            // Series grouping was already off, can't fallback further
                            throw decodingError
                        }
                    }
                    
                } else {
                    throw AudiobookshelfError.libraryNotFound("Selected library not found")
                }
            } else {
                let libraries = try await api.fetchLibraries()
                if let firstLibrary = libraries.first {
                    libraryName = firstLibrary.name
                    
                    fetchedBooks = try await api.fetchBooks(
                        from: firstLibrary.id,
                        limit: 0,
                        collapseSeries: showSeriesGrouped
                    )
                    
                    UserDefaults.standard.set(firstLibrary.id, forKey: "selected_library_id")
                } else {
                    libraryName = "Keine Bibliothek"
                    fetchedBooks = []
                }
            }
            
            withAnimation(.easeInOut) {
                books = fetchedBooks
            }
            
            CoverPreloadHelpers.preloadIfNeeded(
                books: fetchedBooks,
                api: api,
                downloadManager: downloadManager,
                limit: 10
            )
            
        } catch let decodingError as DecodingError {
            // Handle decoding errors specifically
            let errorDetails = getDecodingErrorDetails(decodingError)
            
            errorMessage = """
            Failed to load library data.
            
            Error: \(errorDetails)
            
            Please contact your Audiobookshelf administrator to check:
            • Server logs for errors
            • Database integrity
            • Recent metadata changes
            """
            
            showingErrorAlert = true
            AppLogger.debug.debug("[Library] ❌ Decoding error: \(decodingError)")
            
        } catch let networkError as URLError {
            // Handle network errors specifically
            switch networkError.code {
            case .timedOut:
                errorMessage = "Connection timed out. Your library might be very large. Try again or check your network."
            case .notConnectedToInternet:
                errorMessage = "No internet connection. Please check your network settings."
            case .cannotFindHost:
                errorMessage = "Cannot reach server. Please verify your server address in settings."
            default:
                errorMessage = "Network error: \(networkError.localizedDescription)"
            }
            
            showingErrorAlert = true
            AppLogger.debug.debug("[Library] ❌ Network error: \(networkError)")
            
        } catch {
            // Handle all other errors
            handleError(error)
            AppLogger.debug.debug("[Library] ❌ Fehler beim Laden der Bücher: \(error)")
        }
        
        isLoading = false
    }

    // Helper method to extract detailed decoding error info
    private func getDecodingErrorDetails(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))"
            
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))"
            
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))"
            
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: " → ")): \(context.debugDescription)"
            
        @unknown default:
            return "Unknown decoding error"
        }
    }
    
    @MainActor
    func playBook(_ book: Book, appState: AppStateManager, restoreState: Bool = true) async {
        await loadAndPlayBook(
            book,
            api: api,
            player: player,
            downloadManager: downloadManager,
            appState: appState,
            restoreState: restoreState,
            onSuccess: onBookSelected
        )
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

extension LibraryViewModel {
    var uiState: LibraryUIState {
        if isLoading {
            return .loading
        } else if let error = errorMessage {
            return .error(error)
        } else if books.isEmpty {
            return .empty
        } else if filteredAndSortedBooks.isEmpty && showDownloadedOnly {
            return .noDownloads
        } else if filteredAndSortedBooks.isEmpty {
            return .noSearchResults
        } else {
            return .content
        }
    }
}
