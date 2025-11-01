import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var personalizedSections: [PersonalizedSection] = []
    @Published var libraryName: String = "Personalized"
    @Published var totalBooksInLibrary: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    // For smooth transistions
    @Published var contentLoaded = false
    @Published var sectionsLoaded = false
    
    // Offline mode tracking
    @Published var dataSource: DataSource = .network(timestamp: Date())
    
    // MARK: - Dependencies (Use Cases & Repositories)
    private let fetchPersonalizedSectionsUseCase: FetchPersonalizedSectionsUseCaseProtocol
    private let playBookUseCase: PlayBookUseCase
    private let downloadRepository: DownloadRepository
    private let libraryRepository: LibraryRepositoryProtocol
    
    let api: AudiobookshelfClient
    let downloadManager: DownloadManager
    let player: AudioPlayer
    let appState: AppStateManager
    let onBookSelected: () -> Void
    
    // MARK: - Computed Properties for UI
    var totalItemsCount: Int {
        totalBooksInLibrary
    }
    
    var downloadedCount: Int {
        //let allBooks = getAllBooksFromSections()
        // we do not want the number of downloaded books in personalized sections but all downloaded books
        // return allBooks.filter { downloadRepository.getDownloadStatus(for: $0.id).isDownloaded }.count
        return downloadRepository.getDownloadedBooks().count
    }
    
    var uiState: HomeUIState {
        let isOffline = !appState.canPerformNetworkOperations
        
        if isLoading {
            return isOffline ? .loadingFromCache : .loading
        } else if let error = errorMessage {
            return .error(error)
        } else if isOffline && !personalizedSections.isEmpty {
            return .offline(hasCachedData: true)
        } else if personalizedSections.isEmpty {
            return .empty
        } else {
            return .content
        }
    }
    
    // MARK: - Init with DI
    init(
        fetchPersonalizedSectionsUseCase: FetchPersonalizedSectionsUseCaseProtocol,
        downloadRepository: DownloadRepository,
        libraryRepository: LibraryRepositoryProtocol,
        api: AudiobookshelfClient,
        downloadManager: DownloadManager,
        player: AudioPlayer,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void
    ) {
        self.fetchPersonalizedSectionsUseCase = fetchPersonalizedSectionsUseCase
        self.playBookUseCase = PlayBookUseCase()
        self.downloadRepository = downloadRepository
        self.libraryRepository = libraryRepository
        self.api = api
        self.downloadManager = downloadManager
        self.player = player
        self.appState = appState
        self.onBookSelected = onBookSelected
        
        observeNetworkChanges()

    }
    
    // MARK: - Actions (Delegate to Use Cases)
    func loadPersonalizedSectionsIfNeeded() async {
        if personalizedSections.isEmpty {
            await loadPersonalizedSections()
        }
    }
    
    func loadPersonalizedSections() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let selectedLibrary = try await libraryRepository.getSelectedLibrary() else {
                libraryName = "Personalized"
                personalizedSections = []
                totalBooksInLibrary = 0
                isLoading = false
                return
            }
            
            libraryName = "Explore & listen"
            
            // Fetch sections and stats in parallel
            async let sectionsTask = fetchPersonalizedSectionsUseCase.execute(
                libraryId: selectedLibrary.id
            )
            async let statsTask = api.libraries.fetchLibraryStats(libraryId: selectedLibrary.id)
            
            let (fetchedSections, totalBooks) = try await (sectionsTask, statsTask)
            
            // Success from network
            dataSource = .network(timestamp: Date())
            
            withAnimation(.easeInOut) {
                personalizedSections = fetchedSections
                totalBooksInLibrary = totalBooks
            }
            
            CoverPreloadHelpers.preloadIfNeeded(
                books: getAllBooksFromSections(),
                api: api,
                downloadManager: downloadManager,
                limit: 10
            )
            
        } catch let error as RepositoryError {
            // On error, check if we have cached data from previous successful load
            if !personalizedSections.isEmpty {
                dataSource = .cache(timestamp: Date())
                AppLogger.general.debug("[HomeViewModel] Using in-memory cached data, network unavailable")
            } else {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
                AppLogger.general.debug("[HomeViewModel] Repository error: \(error)")
            }
        } catch {
            if !personalizedSections.isEmpty {
                dataSource = .cache(timestamp: Date())
            } else {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
        
        isLoading = false
    }

    func playBook(_ book: Book, appState: AppStateManager, restoreState: Bool = true) async {
        isLoading = true
        
        do {
            try await playBookUseCase.execute(
                book: book,
                api: api,
                player: player,
                downloadManager: downloadManager,
                appState: appState,
                restoreState: restoreState
            )
            onBookSelected()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
        
        isLoading = false
    }
    
    func loadSeriesBooks(_ series: Series, appState: AppStateManager) async {
        AppLogger.general.debug("Loading series: \(series.name)")
        
        do {
            guard let library = try await libraryRepository.getSelectedLibrary() else {
                errorMessage = "No library selected"
                showingErrorAlert = true
                return
            }
            
            let bookRepository = BookRepository(api: api, cache: BookCache())
            let seriesBooks = try await bookRepository.fetchSeriesBooks(
                libraryId: library.id,
                seriesId: series.id
            )
            
            if let firstBook = seriesBooks.first {
                await playBook(firstBook, appState: appState)
            }
            
        } catch {
            errorMessage = "Could not load series '\(series.name)': \(error.localizedDescription)"
            showingErrorAlert = true
            AppLogger.general.debug("Error loading series: \(error)")
        }
    }
    
    func searchBooksByAuthor(_ authorName: String, appState: AppStateManager) async {
        AppLogger.general.debug("Searching books by author: \(authorName)")
        
        do {
            guard let library = try await libraryRepository.getSelectedLibrary() else {
                errorMessage = "No library selected"
                showingErrorAlert = true
                return
            }
            
            let bookRepository = BookRepository(api: api, cache: BookCache())
            let allBooks = try await bookRepository.fetchBooks(
                libraryId: library.id,
                collapseSeries: false
            )
            
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
            AppLogger.general.debug("Error searching books by author: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    private func getAllBooksFromSections() -> [Book] {
        var allBooks: [Book] = []
        
        for section in personalizedSections {
            let sectionBooks = section.entities
                .compactMap { $0.asLibraryItem }
                .compactMap { api.converter.convertLibraryItemToBook($0) }
            
            allBooks.append(contentsOf: sectionBooks)
        }
        
        return allBooks
    }
    
    // to switch datasoruce from .network to .cache in case no network is available
    
    private func observeNetworkChanges() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for await _ in appState.$isDeviceOnline.values.dropFirst() {
                self.updateDataSourceBasedOnNetwork()
            }
        }
    }
    
    private func updateDataSourceBasedOnNetwork() {
        if !appState.canPerformNetworkOperations {
            dataSource = .cache(timestamp: Date())
        } else {
            dataSource = .network(timestamp: Date())
        }
        
    }
}
