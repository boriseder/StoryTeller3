import SwiftUI

class HomeViewModel: BaseViewModel {
    @Published var personalizedSections: [PersonalizedSection] = []
    @Published var libraryName: String = "Personalized"
    @Published var libraries: [Library] = []

    let api: AudiobookshelfAPI
    let player: AudioPlayer
    let downloadManager: DownloadManager
    let onBookSelected: () -> Void
    
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
            let availableLibraries: [Library]
            if libraries.isEmpty {
                availableLibraries = try await api.fetchLibraries()
                libraries = availableLibraries
            } else {
                availableLibraries = libraries
            }
            
            let selectedLibrary: Library
            if let savedId = LibraryHelpers.getCurrentLibraryId(),
               let found = availableLibraries.first(where: { $0.id == savedId }) {
                selectedLibrary = found
            } else if let first = availableLibraries.first {
                selectedLibrary = first
                LibraryHelpers.saveLibrarySelection(first.id)
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
            
            CoverPreloadHelpers.preloadIfNeeded(
                books: getAllBooksFromSections(),
                api: api,
                downloadManager: downloadManager,
                limit: 10
            )
            
        } catch {
            handleError(error)
            AppLogger.debug.debug("Error loading personalized sections: \(error)")
        }
        
        isLoading = false
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

    @MainActor
    func loadSeriesBooks(_ series: Series, appState: AppStateManager) async {
        AppLogger.debug.debug("Loading series: \(series.name)")
        
        do {
            let libraryId = try LibraryHelpers.requireLibraryId()
            
            let seriesBooks = try await api.fetchSeriesSingle(from: libraryId, seriesId: series.id)
            
            if let firstBook = seriesBooks.first {
                await playBook(firstBook, appState: appState)
            }
            
        } catch {
            errorMessage = "Could not load series '\(series.name)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.debug.debug("Error loading series: \(error)")
        }
    }
    
    @MainActor
    func searchBooksByAuthor(_ authorName: String, appState: AppStateManager) async {
        AppLogger.debug.debug("Searching books by author: \(authorName)")
        
        do {
            let libraryId = try LibraryHelpers.requireLibraryId()
            
            let allBooks = try await api.fetchBooks(from: libraryId, limit: 0, collapseSeries: false)
            let authorBooks = allBooks.filter { book in
                book.author?.localizedCaseInsensitiveContains(authorName) == true
            }
            
            if let firstBook = authorBooks.first {
                await playBook(firstBook, appState: appState)
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
