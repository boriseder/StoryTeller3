import SwiftUI

@MainActor
class SeriesViewModel: ObservableObject {
    // MARK: - Published UI State
    @Published var series: [Series] = []
    @Published var filterState = SeriesFilterState()
    @Published var libraryName: String = "Serien"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert = false
    
    // For smooth transistions
    @Published var contentLoaded = false

    // Offline mode tracking
    @Published var dataSource: DataSource = .network(timestamp: Date())

    // MARK: - Dependencies
    private let fetchSeriesUseCase: FetchSeriesUseCaseProtocol
    private let playBookUseCase: PlayBookUseCase
    private let downloadRepository: DownloadRepository
    private let libraryRepository: LibraryRepositoryProtocol
    
    let api: AudiobookshelfClient
    let downloadManager: DownloadManager
    let player: AudioPlayer
    let appState: AppStateManager
    let onBookSelected: () -> Void
    
    // MARK: - Computed Properties for UI
    var filteredAndSortedSeries: [Series] {
        let filtered = series.filter { filterState.matchesSearchFilter($0) }
        return filterState.applySorting(to: filtered)
    }
    
    var uiState: SeriesUIState {
        let isOffline = !appState.canPerformNetworkOperations
        
        if isLoading {
            return isOffline ? .loadingFromCache : .loading
        } else if let error = errorMessage {
            return .error(error)
        } else if isOffline && !series.isEmpty {
            return .offline(cachedItemCount: series.count)
        } else if series.isEmpty {
            return .empty
        } else if filteredAndSortedSeries.isEmpty && !series.isEmpty {
            return .noDownloads
        } else if filteredAndSortedSeries.isEmpty {
            return .noSearchResults
        } else {
            return .content
        }
    }

    
    
    // MARK: - Init with DI
    init(
        fetchSeriesUseCase: FetchSeriesUseCaseProtocol,
        downloadRepository: DownloadRepository,
        libraryRepository: LibraryRepositoryProtocol,
        api: AudiobookshelfClient,
        downloadManager: DownloadManager,
        player: AudioPlayer,
        appState: AppStateManager,
        onBookSelected: @escaping () -> Void
    ) {
        self.fetchSeriesUseCase = fetchSeriesUseCase
        self.playBookUseCase = PlayBookUseCase()
        self.downloadRepository = downloadRepository
        self.libraryRepository = libraryRepository
        self.api = api
        self.downloadManager = downloadManager
        self.player = player
        self.appState = appState
        self.onBookSelected = onBookSelected
    }
    
    // MARK: - Actions
    func loadSeriesIfNeeded() async {
        if series.isEmpty {
            await loadSeries()
        }
    }
    
    func loadSeries() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let selectedLibrary = try await libraryRepository.getSelectedLibrary() else {
                libraryName = "Series"
                series = []
                isLoading = false
                return
            }

            libraryName = "Series"

            // Try network fetch
            let fetchedSeries = try await fetchSeriesUseCase.execute(
                libraryId: selectedLibrary.id
            )
            
            // Success from network
            dataSource = .network(timestamp: Date())
            
            withAnimation(.easeInOut) {
                series = fetchedSeries
            }
            
        } catch let error as RepositoryError {
            // Repository already tried cache - check if we have data
            if !series.isEmpty {
                // We have cached data from previous fetch
                dataSource = .cache(timestamp: Date())
                AppLogger.general.debug("[SeriesViewModel] Using cached data, network unavailable")
            } else {
                // No cached data available
                handleRepositoryError(error)
            }
        } catch {
            if !series.isEmpty {
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
    
    func convertLibraryItemToBook(_ item: LibraryItem) -> Book? {
        return api.converter.convertLibraryItemToBook(item)
    }
    
    // MARK: - Error Handling
    private func handleRepositoryError(_ error: RepositoryError) {
        errorMessage = error.localizedDescription
        showingErrorAlert = true
        AppLogger.general.debug("[SeriesViewModel] Repository error: \(error)")
    }
}
